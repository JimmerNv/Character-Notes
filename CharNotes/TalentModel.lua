local _, CN = ...
local P = {}
CN.talents = P

-- Forever's single specialization per class opens the client-owned read-only preview.
P.spec = { MAGE=1482, DRUID=1484, HUNTER=1485, PALADIN=1486, PRIEST=1487,
    ROGUE=1488, SHAMAN=1489, WARLOCK=1490, WARRIOR=1491 }
P.classes = {'WARRIOR','PALADIN','HUNTER','ROGUE','PRIEST','SHAMAN','MAGE','WARLOCK','DRUID'}
local cache = {}

function P.blank(class)
    return {class = class or select(2, UnitClass('player')), ranks = {}, choices = {}}
end

function P.copy(build)
    if not build then return nil end
    local result = P.blank(build.class)
    for id, rank in pairs(build.ranks) do result.ranks[id] = rank end
    for id, entry in pairs(build.choices or {}) do result.choices[id] = entry end
    return result
end

local function requirement(config, conditions)
    local points = 0
    for _, id in ipairs(conditions or {}) do
        local info = assert(C_Traits.GetConditionInfo(config, id))
        points = math.max(points, info.spentAmountRequired or 0)
    end
    return points
end

local function layout(tree)
    -- Ignore isolated off-grid coordinates present in some Forever builds.
    local xs, ys = {}, {}
    for _, n in ipairs(tree.nodes) do
        xs[#xs+1] = n.x
        ys[#ys+1] = n.y
    end
    table.sort(xs)
    table.sort(ys)
    assert(#xs > 0)
    local mid = math.ceil(#xs/2)
    local left, top = math.huge, math.huge
    for i = #tree.nodes, 1, -1 do
        local n = tree.nodes[i]
        if math.abs(n.x-xs[mid]) > 2400 or math.abs(n.y-ys[mid]) > 4200 then
            table.remove(tree.nodes, i)
        else
            left, top = math.min(left,n.x), math.min(top,n.y)
        end
    end
    assert(#tree.nodes > 0)
    for _, n in ipairs(tree.nodes) do
        n.col = math.floor((n.x-left)/600+.5)
        n.row = math.floor((n.y-top)/600+.5)
        tree.cols = math.max(tree.cols or 4, n.col+1)
        tree.rows = math.max(tree.rows or 7, n.row+1)
    end
end

local function readModel(class)
    local spec = assert(P.spec[class])
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 60
    local config = Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID
    C_ClassTalents.InitializeViewLoadout(spec, maxLevel)
    local id = assert(C_ClassTalents.GetTraitTreeForSpec(spec))
    local groups = assert(C_Traits.GetGroupDisplayInfoByTreeID(id))
    assert(#groups == 3)
    table.sort(groups, function(a,b) return a.orderIndex < b.orderIndex end)
    local model = {id=id, class=class, trees={}, nodes={}, cap=maxLevel-9}
    local grouped = {}
    for i, group in ipairs(groups) do
        local tree = {name=group.displayName, nodes={}, index=i}
        model.trees[i], grouped[group.groupID] = tree, tree
    end
    for _, nodeID in ipairs(assert(C_Traits.GetTreeNodes(id))) do
        local info = assert(C_Traits.GetNodeInfo(config, nodeID))
        local tree
        for _, groupID in ipairs(info.groupIDs or {}) do tree = tree or grouped[groupID] end
        if tree and info.isVisible ~= false and (info.maxRanks or 0)>0 and info.entryIDs and #info.entryIDs>0 then
            local node = {id=nodeID, tree=tree.index, max=info.maxRanks, x=info.posX, y=info.posY,
                cost=requirement(config,info.conditionIDs), entries={}, required={}, any={}, edges=info.visibleEdges}
            for _, entryID in ipairs(info.entryIDs) do
                local entry = assert(C_Traits.GetEntryInfo(config, entryID))
                local def = assert(C_Traits.GetDefinitionInfo(entry.definitionID))
                node.entries[#node.entries+1] = {id=entryID, spell=def.spellID,
                    name=def.overrideName, icon=def.overrideIcon, cost=requirement(config,entry.conditionIDs)}
            end
            tree.nodes[#tree.nodes+1] = node
        end
    end
    for _, tree in ipairs(model.trees) do
        layout(tree)
        for _, node in ipairs(tree.nodes) do model.nodes[node.id] = node end
    end
    for _, node in pairs(model.nodes) do
        for _, edge in ipairs(node.edges or {}) do
            local target = model.nodes[edge.targetNode]
            if target then
                local types = Enum.TraitEdgeType
                if edge.type == types.RequiredForAvailability then
                    target.required[#target.required+1] = node.id
                elseif edge.type == types.SufficientForAvailability then
                    target.any[#target.any+1] = node.id
                end
            end
        end
    end
    local currencies = C_Traits.GetTreeCurrencyInfo(config,id,false)
    local currency = currencies and currencies[1]
    local cap = currency and (currency.quantity or 0)+(currency.spent or 0)
    if cap and cap > 0 then model.cap = cap end
    return model
end

function P.model(class)
    if cache[class] then return cache[class] end
    -- The same view slot is used for Blizzard's talent links.
    if (PlayerSpellsFrame and PlayerSpellsFrame:IsShown()) or (InCombatLockdown and InCombatLockdown()) then return end
    local ok, model = pcall(readModel,class)
    if ok then cache[class] = model; return model end
end

function P.entry(node, build)
    local choice = build.choices and build.choices[node.id]
    for _, entry in ipairs(node.entries) do
        if choice == nil or entry.id == choice then return entry end
    end
end

function P.totals(model, build)
    local sum, trees = 0, {0,0,0}
    for id, rank in pairs(build.ranks) do
        local n = model.nodes[id]
        if n then trees[n.tree] = trees[n.tree]+rank; sum = sum+rank end
    end
    return sum, trees
end

local function unlocked(node, model, ranks, spent, entry)
    if spent[node.tree] < math.max(node.cost, entry.cost) then return false end
    for _, id in ipairs(node.required) do
        if (ranks[id] or 0)<model.nodes[id].max then return false end
    end
    for _, id in ipairs(node.any) do
        if (ranks[id] or 0)==model.nodes[id].max then return true end
    end
    return #node.any == 0
end

function P.canAdd(model, build, node, used, spent)
    local entry = P.entry(node, build)
    return entry and used < model.cap and (build.ranks[node.id] or 0) < node.max
        and unlocked(node, model, build.ranks, spent, entry)
end

-- Replay the requested allocation from zero. This also catches refunds that
-- would strand a higher row or leave a cycle of mutually supporting points.
function P.valid(model, build)
    if not model or build.class ~= model.class then return false end
    local pending, placed, spent = {}, {}, {0,0,0}
    local total = 0
    for id, rank in pairs(build.ranks) do
        local node = model.nodes[id]
        if not node or type(rank) ~= 'number' or rank < 1 or rank > node.max or rank%1 ~= 0
            or not P.entry(node,build) then return false end
        pending[id] = rank
        total = total + rank
    end
    if total > model.cap then return false end
    while next(pending) do
        local changed = false
        for id, rank in pairs(pending) do
            local node = model.nodes[id]
            if unlocked(node,model,placed,spent,P.entry(node,build)) then
                placed[id],pending[id] = rank,nil
                spent[node.tree] = spent[node.tree]+rank
                changed = true
            end
        end
        if not changed then return false end
    end
    return true
end

function P.adjust(model, build, id, delta)
    local candidate = P.copy(build)
    local rank = (candidate.ranks[id] or 0)+delta
    candidate.ranks[id] = rank ~= 0 and rank or nil
    if P.valid(model,candidate) then return candidate end
end

function P.capture(model)
    local build = P.blank()
    if not model or build.class ~= model.class then return end
    local function read()
        local spec = C_SpecializationInfo
        local config = assert(spec.GetCombatConfigIDForSpecGroup(spec.GetActiveSpecGroup() or 1))
        if C_Traits.ConfigHasStagedChanges and C_Traits.ConfigHasStagedChanges(config) then return end
        local info = assert(C_Traits.GetConfigInfo(config))
        local found = false
        for _, id in ipairs(info.treeIDs) do if id == model.id then found = true end end
        if not found then return end
        for _, id in ipairs(assert(C_Traits.GetTreeNodes(model.id))) do
            local n = assert(C_Traits.GetNodeInfo(config,id))
            if (assert(n.ranksPurchased)) > 0 then
                if not model.nodes[id] then return end
                build.ranks[id] = n.ranksPurchased
                if n.activeEntry then build.choices[id] = n.activeEntry.entryID end
            end
        end
        if P.valid(model,build) then return build end
    end
    local ok, result = pcall(read)
    if ok then return result end
end
