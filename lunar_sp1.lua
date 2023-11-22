local extension = Package("lunar_sp1")
extension.extensionName = "lunar"

local U = require "packages/utility/utility"

Fk:loadTranslationTable{
  lunar_sp1 = "新月杀专属",
  fk = "新月",
}

-- 新月杀第一届DIY选拔： 吕伯奢，郭攸之

local lvboshe = General(extension, "fk__lvboshe", "qun", 4)
local kuanyanTrig = fk.CreateTriggerSkill{
  name = "#fk__kuanyan",
  mute = true,
  events = {fk.CardUsing},
  can_trigger = function(self, event, target, player, data)
    if player:hasSkill(self) and player:getMark("fk__kuanyan") == target.id then
      return player:getMark("fk__kuanyan" .. data.card.type .. "-turn") == 0 and
        (data.card.type == Card.TypeBasic or data.card.type == Card.TypeTrick)
    end
  end,
  on_cost = function() return true end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:broadcastSkillInvoke("fk__kuanyan")
    room:notifySkillInvoked(player, "fk__kuanyan")
    room:addPlayerMark(player, "fk__kuanyan" .. data.card.type .. "-turn", 1)

    player:drawCards(2, "fk__kuanyan")
    local card = room:askForCard(player, 1, 1, true, "fk__kuanyan", false, ".", "#fk__kuanyan-ask:" .. target.id)
    room:obtainCard(target.id, card[1], false, fk.ReasonGive)

    if not table.find(room:getOtherPlayers(target), function(p)
      return p.hp > target.hp
    end) then
      room:recover{
        who = target,
        recoverBy = player,
        skillName = "fk__kuanyan",
        num = 1,
      }
    end
  end,

  refresh_events = {fk.EventPhaseStart},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill("fk__kuanyan") and player.phase == Player.RoundStart
  end,
  on_refresh = function(_, _, _, player)
    player.room:setPlayerMark(player, "fk__kuanyan", 0)
  end,
}
local kuanyan = fk.CreateActiveSkill{
  name = "fk__kuanyan",
  anim_type = "support",
  can_use = function (self, player, card)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_num = 1,
  target_num = 1,
  card_filter = function(self, to_select, selected)
    return #selected == 0
  end,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id
  end,
  on_use = function (self, room, effect)
    local from = room:getPlayerById(effect.from)
    local to = room:getPlayerById(effect.tos[1])
    local card = effect.cards[1]

    room:throwCard(card, self.name, from, from)
    room:setPlayerMark(from, self.name, to.id)
    room:setPlayerMark(to, "fk__kuanyan_target", 1)
  end
}
kuanyan:addRelatedSkill(kuanyanTrig)
lvboshe:addSkill(kuanyan)
local gufu = fk.CreateProhibitSkill{
  name = "fk__gufu",
  frequency = Skill.Compulsory,
  prohibit_use = function(self, player, card)
    if not player:hasSkill(self) then return end
    local current = table.find(Fk:currentRoom().alive_players, function(p)
      return p.phase ~= Player.NotActive
    end)
    if not current then return false end
    return current:getMark("fk__kuanyan_target") ~= 0
  end,
  prohibit_response = function(self, player, card)
    if not player:hasSkill(self) then return end
    local current = table.find(Fk:currentRoom().alive_players, function(p)
      return p.phase ~= Player.NotActive
    end)
    if not current then return false end
    return current:getMark("fk__kuanyan_target") ~= 0
  end,
}
lvboshe:addSkill(gufu)
Fk:loadTranslationTable{
  ["fk__lvboshe"] = "吕伯奢",
  ["designer:fk__lvboshe"] = "一如遥远往昔",
  ["fk__kuanyan"] = "款宴",
  [":fk__kuanyan"] = "出牌阶段限一次，你可以弃置一张牌并选择一名其他角色，" ..
    "直至你的下个回合开始，该角色每回合使用第一张基本牌和锦囊牌后，" ..
    "你摸两张牌并交给其一张牌，若其体力值为全场最低，其回复一点体力。",
  ["#fk__kuanyan-ask"] = "款宴: 请交给 %src 一张牌",
  ["fk__gufu"] = "故负",
  [":fk__gufu"] = "锁定技，在成为过〖款宴〗目标的角色回合内，你不能使用或打出手牌。",
}

local guoyouzhi = General(extension, "fk__guoyouzhi", "shu", 3)
local fk__zhongyu = fk.CreateTriggerSkill{
  name = "fk__zhongyu",
  anim_type = "support",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and target ~= player and target.phase == Player.Play
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, nil, "#fk__zhongyu-invoke:" .. target.id)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:drawCards(1, self.name)
    target:drawCards(1, self.name)
    --[[
    local tos = {player, target}
    local extraData = {
      num = 1,
      min_num = 1,
      include_equip = true,
      pattern = ".|.|.|hand,equip|.|.",
      reason = self.name,
    }
    local j = json.encode(extraData)
    for _, p in ipairs(tos) do
      p.request_data = json.encode {
        "discard_skill",
        "#fk__zhongyu-discard",
        true,
        j,
      }
    end
    room:notifyMoveFocus(tos, self.name)
    room:doBroadcastRequest("AskForUseActiveSkill", tos)
    local move = {}
    local colors = {}
    for _, p in ipairs(tos) do
      local id
      if p.reply_ready then
        local replyCard = json.decode(p.client_reply).card
        id = json.decode(replyCard).subcards[1]
      else
        id = table.random(p:getCardIds{Player.Hand, Player.Equip})
      end
      table.insertIfNeed(colors, Fk:getCardById(id):getColorString())
      table.insert(move, {
        from = p.id,
        ids = {id},
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonDiscard,
        proposer = p.id,
        skillName = self.name,
        moveVisible = true
      })
    end
    room:moveCards(table.unpack(move))
    --]]
    if (player:isAllNude() or target:isAllNude()) then return end
    local id1 = room:askForDiscard(player, 1, 1, true, self.name, false, ".", "#fk__zhongyu-discard")[1]
    local id2 = room:askForDiscard(target, 1, 1, true, self.name, false, ".", "#fk__zhongyu-discard")[1]

    if Fk:getCardById(id1).color == Fk:getCardById(id2).color then
      target:drawCards(1, self.name)
    end
  end,
}
local fk__yicha = fk.CreateTriggerSkill{
  name = "fk__yicha",
  anim_type = "control",
  -- events = {fk.CardUsing},
  events = {fk.BeforeDrawCard, fk.StartJudge},
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(self) then return false end 
    if event == fk.BeforeDrawCard then return data.num >= 1 end
    --[[
    local x = player:getMark("fk__yicha-turn")
    if x ~= 0 then x = #x end
    return player:getHandcardNum() >= x
    --]]
    return true
  end,
  on_cost = function(self, event, target, player, data)
    local x = player:getMark("fk__yicha-turn")
    if x ~= 0 then x = #x end
    x = 5 - x
    return player.room:askForSkillInvoke(player, self.name, nil, "#fk__yicha-invoke:::" .. x)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local x = player:getMark("fk__yicha-turn")
    if x ~= 0 then x = #x end
    x = 5 - x
    if #room.draw_pile < x then
      room:shuffleDrawPile()
      if #room.draw_pile < x then
        room:gameOver("")
      end
    end
    local cids = table.slice(room.draw_pile, 1, x + 1)
    -- room:fillAG(player, cids)
    -- room:delay(3000)
    -- local card_arg = table.concat(table.map(cids,
    --   function(id) return Fk:getCardById(id):toLogString() end), ",")

    --[[
    local choices = {
      "#fk__yicha-cDiscard",
      -- "#fk__yicha-cExchange",
      -- "#fk__yicha-cGuan"
    }
    local all_choices = {
      "#fk__yicha-cDiscard", "#fk__yicha-cExchange", "#fk__yicha-cGuan",
      "%arg:::" .. card_arg
    }
    local choice = room:askForChoice(player, choices, self.name,
      "#fk__yicha-choice:::" .. 5 - x .. ":" .. card_arg, false) --, all_choices)
    if choice == "#fk__yicha-cDiscard" then
      -- room:closeAG(player)
    --]]
    local to_discard = room:askForCardsChosen(player, player, 0, #cids, {
      card_data = {
        { "Top", cids }
      }
    }, self.name, "#fk__yicha-discard:::" .. x)
    room:moveCardTo(to_discard, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile, self.name)
      --[[
    elseif choice == "#fk__yicha-cExchange" then
      local cidsE = room:askForCard(player, 1, 1, true, self.name, false, ".|.|.|hand", "#fk__yicha-cExchange-choose")
      if #cidsE < 1 then
        cidsE = table.random(player:getCardIds({Player.Hand, Player.Equip}), 1)
      end
      -- room:closeAG(player)
      local ret = room:askForExchange(player, { cids, cidsE }, { "Top", player.general })
      local takedown = ret[2]
      local insPos = table.indexOf(cids, takedown[1])
      room:moveCards(
        {
          ids = takedown,
          to = player.id,
          toArea = Card.PlayerHand,
          moveReason = fk.ReasonExchange,
          proposer = player.id,
          skillName = self.name,
        },
        {
          ids = cidsE,
          from = player.id,
          toArea = Card.DrawPile,
          moveReason = fk.ReasonExchange,
          proposer = player.id,
          skillName = self.name,
          drawPilePosition = insPos
        }
      )
    elseif choice == "#fk__yicha-cGuan" then
      -- room:closeAG(player)
      room:askForGuanxing(player, room:getNCards(5 - x), nil, { 0, 0 }, self.name)
    end
    --]]
  end,

  refresh_events = {fk.AfterCardsMove},
  can_refresh = function(self, event, target, player, data)
    if player:hasSkill(self, true) then
      local room = player.room
      for _, move in ipairs(data) do
        if move.toArea == Card.DiscardPile then
          local tmp = table.simpleClone(player:getMark("fk__yicha-turn") ~= 0 and player:getMark("fk__yicha-turn") or {})
          for _, info in ipairs(move.moveInfo) do
            table.insertIfNeed(tmp, Fk:getCardById(info.cardId):getSuitString(true))
          end
          room:setPlayerMark(player, "fk__yicha-turn", tmp)
          return player:getMark("fk__yicha-turn") ~= 0
        end
      end
    end
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@fk__yicha-turn", table.concat(table.map(player:getMark("fk__yicha-turn"), function(s) return Fk:translate(s) end)))
  end
}
guoyouzhi:addSkill(fk__zhongyu)
guoyouzhi:addSkill(fk__yicha)
Fk:loadTranslationTable{
  ['fk__guoyouzhi'] = '郭攸之',
  ['designer:fk__guoyouzhi'] = 's1134s',
  ['fk__zhongyu'] = '忠喻',
  [':fk__zhongyu'] = '其他角色的出牌阶段开始时，你可以与其各摸一张牌' ..
    '并依次弃置一张牌，若弃置的两张牌的颜色相同，其摸一张牌。',
  ['#fk__zhongyu-invoke'] = '忠喻：你可与 %src 各摸一张牌',
  -- ['#fk__zhongyu-invokeR'] = '忠喻：你可继续与 %src 各摸一张牌',
  ['#fk__zhongyu-discard'] = '忠喻：你须弃置一张牌',
  ['@fk__zhongyu-phase'] = '忠喻',
  ['fk__yicha'] = '益察',
  [':fk__yicha'] = '当你即将判定或者摸牌时，你可以观看牌堆顶的5-X张牌' ..
    '并将其中任意张牌置入弃牌堆。（X为本回合内进入弃牌堆内的牌的总花色数）',
  ['#fk__yicha-invoke'] = '益察：你可观看牌堆顶 %arg 张牌并将其中任意张牌置入弃牌堆',
  --['#fk__yicha-choice'] = '益察：牌堆顶的 %arg 牌分别是 %arg2 , 请选择一种操作',
  --['#fk__yicha-cDiscard'] = '弃置任意张牌',
  --['#fk__yicha-cExchange'] = '用一张牌与其中一张牌交换',
  --['#fk__yicha-cExchange-choose'] = '益察：你须选择一张牌',
  --['#fk__yicha-cGuan'] = '以任意顺序置于牌堆顶',
  ['@fk__yicha-turn'] = '益察',
  ["#fk__yicha-discard"] = "益察：观看牌堆顶 %arg 张牌，可将其中任意张牌置入弃牌堆",
}

-- 新月杀第三届DIY选拔： 应玚，柳隐，张布，张葳
-- 主催：理塘王

local yingyang = General(extension, "fk__yingyang", "wei", 3)
local fk__guici = fk.CreateTriggerSkill{
  name = "fk__guici",
  events = {fk.RoundStart},
  anim_type = "switch",
  switch_skill_name = "fk__guici",
  frequency = Skill.Compulsory,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local patternTable = {}
    if player:getSwitchSkillState(self.name, true) == fk.SwitchYang then
      patternTable = { ["heart"] = {}, ["diamond"] = {}, ["spade"] = {}, ["club"] = {} }
      for _, id in ipairs(room.draw_pile) do
        local pattern = Fk:getCardById(id):getSuitString()
        if patternTable[pattern] then
          table.insert(patternTable[pattern], id)
        end
      end
    else
      patternTable = { ["basic"] = {}, ["trick"] = {}, ["equip"] = {} }
      for _, id in ipairs(room.draw_pile) do
        local pattern = Fk:getCardById(id):getTypeString()
        if patternTable[pattern] then
          table.insert(patternTable[pattern], id)
        end
      end
    end
    local get = {}
    for _, ids in pairs(patternTable) do
      if #ids > 0 then
        table.insert(get, table.random(ids))
      end
    end
    if #get > 0 then
      local dummy = Fk:cloneCard("dilu")
      dummy:addSubcards(get)
      room:obtainCard(player, dummy, false, fk.ReasonPrey)
      local handcards = player:getCardIds("h")
      for _, id in ipairs(get) do
        if table.contains(handcards, id) then
          room:setCardMark(Fk:getCardById(id), "@@fk__guici-inhand", 1)
        end
      end
    end
  end,
}
yingyang:addSkill(fk__guici)
local fk__beili = fk.CreateTriggerSkill{
  name = "fk__beili",
  events = {fk.Damaged},
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and not target.dead and not player:isNude()
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local card = room:askForDiscard(player, 1, 1, true, self.name, true, ".", "#fk__beili-discard::"..target.id, true)
    if #card > 0 then
      self.cost_data = card
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local draw = Fk:getCardById(self.cost_data[1]):getMark("@@fk__guici-inhand") > 0
    room:throwCard(self.cost_data, self.name, player, player)
    if not target.dead then
      target:drawCards(1, self.name)
    end
    if draw and not player.dead then
      player:drawCards(1, self.name)
    end
  end,
}
yingyang:addSkill(fk__beili)
Fk:loadTranslationTable{
  ["fk__yingyang"] = "应玚",
  ["designer:fk__yingyang"] = "小嘤嘤",
  ["fk__guici"] = "瑰词",
  [":fk__guici"] = "转换技，锁定技，每轮开始时，你从牌堆中获得：阳：四张花色各不相同的牌；阴：三张类型各不相同的牌。",
  ["@@fk__guici-inhand"] = "瑰词",
  ["fk__beili"] = "悲离",
  [":fk__beili"] = "每当一名角色受到伤害后，你可以弃置一张牌，令其摸一张牌，若你以此法弃置了“瑰词”牌，你摸一张牌。",
  ["#fk__beili-discard"] = "悲离：你可弃一张牌，令 %dest 摸一张牌，若弃置“瑰词”牌，你摸一张牌。",

  -- CV：万事屋
  ["$fk__guici1"] = "涉津洛之阪泉兮，播九道乎中州。",
  ["$fk__guici2"] = "衔积石之重险兮，披山麓而溢浮。",
  ["$fk__beili1"] = "有鸟孤栖，哀鸣北林。嗟我怀矣，感物伤心。",
  ["$fk__beili2"] = "朝雁鸣云中，音响一何哀。",
  ["~fk__yingyang"] = "胸中千言未述…所志皆不遂…",
}
local liuyin = General(extension, "fk__liuyin", "shu", 4)
local fk__gushou = fk.CreateTriggerSkill{
  name = "fk__gushou",
  events = {fk.DamageInflicted},
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and player == target
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local choices = {}
    if not player:isNude() and player:getMark("fk__gushou_discard-turn") == 0 then table.insert(choices, "fk__gushou_discard") end
    if player.hp > 0 and player:getMark("fk__gushou_losehp-turn") == 0 then table.insert(choices, "fk__gushou_losehp") end
    if #choices == 0 then return false end
    if #choices > 1 then table.insert(choices, "Cancel") end
    local choice = room:askForChoice(player, choices, self.name)
    if choice == "fk__gushou_discard" then
      local card = room:askForDiscard(player, 1, 1, true, self.name, #choices == 1, ".", "#fk__gushou-discard", true)
      if #card > 0 then
        self.cost_data = {choice, card}
        return true
      end
    elseif choice == "fk__gushou_losehp" then
      if #choices > 1 or room:askForSkillInvoke(player, self.name, nil, "#fk__gushou-losehp") then
        self.cost_data = {choice}
        return true
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local choice = self.cost_data[1]
    room:addPlayerMark(player, choice.."-turn")
    if choice == "fk__gushou_discard" then
      room:throwCard(self.cost_data[2], self.name, player, player)
      if not player.dead and player:isWounded() then
        room:recover { num = 1, skillName = self.name, who = player , recoverBy = player}
      end
    else
      room:loseHp(player, 1, self.name)
      if not player.dead then
        player:drawCards(1, self.name)
      end
      return true
    end
  end,
}
liuyin:addSkill(fk__gushou)
local fk__fapi = fk.CreateTriggerSkill{
  name = "fk__fapi",
  events = {fk.EventPhaseStart},
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and player ~= target and target.phase == Player.Finish and player.hp > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, nil, "#fk__fapi-invoke::"..target.id)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:loseHp(player, 1, self.name)
    if not player.dead then
      player:drawCards(1, self.name)
    end
    local card = Fk:cloneCard("slash")
    card.skillName = self.name
    local use = {card = card, from = player.id, tos = {{target.id}}, extraUse = true}
    if not player:isProhibited(target, card) and not player:prohibitUse(card) then
      room:useCard(use)
    end
    if use.damageDealt and not player.dead then
      player:drawCards(1, self.name)
    end
  end,
}
liuyin:addSkill(fk__fapi)
Fk:loadTranslationTable{
  ["fk__liuyin"] = "柳隐",
  ["designer:fk__liuyin"] = "白幽",
  ["fk__gushou"] = "固守",
  [":fk__gushou"] = "每回合每项各限一次，当你受到伤害时，你可以：1.弃置一张牌，然后回复1点体力；2.失去一点体力，防止此伤害，然后摸一张牌。",
  ["fk__gushou_discard"] = "弃置一张牌，然后回复1点体力",
  ["fk__gushou_losehp"] = "失去一点体力，防止此伤害，摸一张牌",
  ["#fk__gushou-losehp"] = "固守：失去一点体力，防止此伤害，然后摸一张牌",
  ["#fk__gushou-discard"] = "固守：弃置一张牌，回复1点体力",
  ["fk__fapi"] = "伐疲",
  [":fk__fapi"] = "其他角色的结束阶段，你可以失去1点体力，摸一张牌，视为对其使用一张无距离限制的【杀】，若此【杀】造成伤害，你摸一张牌。",
  ["#fk__fapi-invoke"] = "伐疲：失去1点体力，摸一张牌，视为对 %dest 使用一张【杀】",

  ["$fk__gushou1"] = "坚守此城，援军不日必至。",
  ["$fk__gushou2"] = "诸将无虑，大将军早有筹谋。",
  ["$fk__fapi1"] = "守城之善者，出城破敌也！",
  ["$fk__fapi2"] = "久战之师，强弩之末，不能穿鲁缟。",
  ["~fk__liuyin"] = "汉臣守土有责，无奈汉主先降！",
}
local zhangbu = General(extension, "fk__zhangbu", "wu", 3)
local fk__guzhu = fk.CreateTriggerSkill{
  name = "fk__guzhu",
  anim_type = "support",
  events = {fk.TargetSpecified},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and data.card.type == Card.TypeBasic and data.firstTarget and not player:isKongcheng()
    and not (data.extra_data and data.extra_data.fk__guzhu)
  end,
  on_cost = function (self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, data, "#fk__guzhu-invoke::"..target.id..":"..data.card.name)
  end,
  on_use = function(self, event, target, player, data)
    player:throwAllCards("h")
    data.extra_data = data.extra_data or {}
    data.extra_data.fk__guzhu = true
  end,

  refresh_events = {fk.CardUseFinished},
  can_refresh = function(self, event, target, player, data)
    return data.extra_data and data.extra_data.fk__guzhu
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:doCardUseEffect(data)
    data.extra_data.fk__guzhu = false
  end,
}
zhangbu:addSkill(fk__guzhu)
local fk__zhuanzheng = fk.CreateTriggerSkill{
  name = "fk__zhuanzheng",
  anim_type = "support",
  events = {fk.AfterCardsMove},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self) or player.hp < 1 then return end
    for _, move in ipairs(data) do
      if move.from and player.room:getPlayerById(move.from):isKongcheng() then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerHand then
            return true
          end
        end
      end
    end
  end,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    local targets = {}
    for _, move in ipairs(data) do
      if move.from and player.room:getPlayerById(move.from):isKongcheng() then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerHand then
            table.insertIfNeed(targets, move.from)
            break
          end
        end
      end
    end
    room:sortPlayersByAction(targets)
    for _, target_id in ipairs(targets) do
      if not player:hasSkill(self) or player.hp < 1 then break end
      local skill_target = room:getPlayerById(target_id)
      if skill_target and not skill_target.dead then
        self:doCost(event, skill_target, player, data)
      end
    end
  end,
  on_cost = function (self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, data, "#fk__zhuanzheng-invoke::"..target.id)
  end,
  on_use = function(self, event, target, player, data)
    player.room:doIndicate(player.id, {target.id})
    player.room:loseHp(player, 1, self.name)
    local x = target.maxHp - target:getHandcardNum()
    if not target.dead and x > 0 then
      target:drawCards(math.min(x, 5), self.name)
    end
  end,
}
zhangbu:addSkill(fk__zhuanzheng)
Fk:loadTranslationTable{
  ["fk__zhangbu"] = "张布",
  ["designer:fk__zhangbu"] = "理塘王",
  ["fk__guzhu"] = "孤注",
  [":fk__guzhu"] = "一名角色使用基本牌指定目标后，你可以弃置所有手牌，令此牌额外结算一次。",
  ["#fk__guzhu-invoke"] = "孤注：你可以弃置所有手牌，令 %dest 使用的 %arg 额外结算一次",
  ["fk__zhuanzheng"] = "专政",
  [":fk__zhuanzheng"] = "一名角色失去手牌后，若其没有手牌，你可以失去1点体力，令其将手牌摸至体力上限（至多摸五张）。",
  ["#fk__zhuanzheng-invoke"] = "专政：你可以失去1点体力，令 %dest 将手牌摸至体力上限（至多摸五张）",

  ["$fk__guzhu1"] = "今进退无路，何不效伊尹霍光？",
  ["$fk__guzhu2"] = "孙綝，虎狼也，岂可安坐待死？",
  ["$fk__zhuanzheng1"] = "国朝之事，皆系我一身。",
  ["$fk__zhuanzheng2"] = "布政之责，使内外无患。",
  ["$fk__zhuanzheng3"] = "放肆！",
  ["~fk__zhangbu"] = "起浮半生如怒涛…终随江水去…",
}

local zhangwei = General(extension, "fk__zhangwei", "qun", 4, 4, General.Female)
local fk__xiaorong = fk.CreateTriggerSkill{
  name = "fk__xiaorong",
  anim_type = "offensive",
  events = {fk.AfterCardTargetDeclared},
  can_trigger = function (self, event, target, player, data)
    return target == player and player:hasSkill(self) and data.card.trueName == "slash" and #TargetGroup:getRealTargets(data.tos) == 1 and table.find(player.room.alive_players, function (p)
      return p:distanceTo(player) == 1
    end)
  end,
  on_cost = function (self, event, target, player, data)
    local room = player.room
    local targets = U.getUseExtraTargets(room, data)
    if #targets > 0 then
      local num = #table.filter(player.room.alive_players, function (p)
        return p:distanceTo(player) == 1
      end)
      local tos = room:askForChoosePlayers(player, targets, 1, num, "#fk__xiaorong:::" .. num, self.name, true)
      if #tos > 0 then
        self.cost_data = tos
        return true
      end
    end
  end,
  on_use = function (self, event, target, player, data)
    table.forEach(self.cost_data, function (id)
      table.insert(data.tos, {id})
    end)
    if #TargetGroup:getRealTargets(data.tos) > player.hp then
      local card = Fk:cloneCard("duel")
      card.skillName = self.name
      card:addSubcard(data.card)
      data.card = card
    end
  end,
}
zhangwei:addSkill(fk__xiaorong)
local fk__yiyong = fk.CreateTriggerSkill{
  name = "fk__yiyong",
  anim_type = "drawcard",
  events = {fk.Damage},
  can_trigger = function (self, event, target, player, data)
    return target == player and player:hasSkill(self) and data.to:getHandcardNum() > player:getHandcardNum()
  end,
  on_use = function (self, event, target, player, data)
    player:drawCards(2, self.name)
    player.room:addPlayerMark(player, "@fk__yiyong-turn")
  end
}
local fk__yiyong_buff = fk.CreateTargetModSkill{
  name = "#fk__yiyong_buff",
  residue_func = function(self, player, skill, scope)
    if player:getMark("@fk__yiyong-turn") ~= 0 and skill.trueName == "slash_skill" and scope == Player.HistoryPhase then
      return player:getMark("@fk__yiyong-turn")
    end
  end,
}
fk__yiyong:addRelatedSkill(fk__yiyong_buff)
zhangwei:addSkill(fk__yiyong)
Fk:loadTranslationTable{
  ["fk__zhangwei"] = "张葳",
  ["designer:fk__zhangwei"] = "郭攸之的设计修改者",
  ["fk__xiaorong"] = "骁戎",
  [":fk__xiaorong"] = "当你使用【杀】选择目标后，若目标角色数为1，你可以令至多X名其他角色也成为此【杀】的目标，然后若此【杀】的目标数大于你的体力值，你令此【杀】改为【决斗】（X为至你距离为1的角色）。",
  ["fk__yiyong"] = "义勇",
  [":fk__yiyong"] = "当你对手牌数大于你的角色造成伤害后，你可以摸两张牌，然后你本回合使用【杀】次数上限+1。",

  ["#fk__xiaorong"] = "骁戎：你可令至多%arg名其他角色成为此【杀】的目标",
  ["@fk__yiyong-turn"] = "义勇",
}
return extension
