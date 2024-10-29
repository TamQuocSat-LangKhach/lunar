local extension = Package("lunar_sp1")
extension.extensionName = "lunar"

local U = require "packages/utility/utility"

Fk:loadTranslationTable{
  ["lunar_sp1"] = "新月杀专属",
  ["fk"] = "新月",
}

-- 新月杀第一届DIY选拔： 吕伯奢，郭攸之

local lvboshe = General(extension, "fk__lvboshe", "qun", 4)
local kuanyan = fk.CreateActiveSkill{
  name = "fk__kuanyan",
  anim_type = "support",
  can_use = function (self, player, card)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0 and not player:isNude()
  end,
  card_num = 1,
  target_num = 1,
  card_filter = function(self, to_select, selected)
    return #selected == 0 and not Self:prohibitDiscard(Fk:getCardById(to_select))
  end,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id
  end,
  on_use = function (self, room, effect)
    local player = room:getPlayerById(effect.from)
    local to = room:getPlayerById(effect.tos[1])
    local card = effect.cards[1]
    room:throwCard(card, self.name, player, player)
    if player.dead or to.dead then return end
    local mark = player:getTableMark(self.name)
    table.insertIfNeed(mark, to.id)
    room:setPlayerMark(player, self.name, mark)
    room:setPlayerMark(to, "fk__kuanyan_target", 1)
  end
}
local kuanyan_delay = fk.CreateTriggerSkill{
  name = "#kuanyan_delay",
  mute = true,
  events = {fk.CardUseFinished},
  can_trigger = function(self, event, target, player, data)
    if player:hasSkill(self) and table.contains(player:getTableMark("fk__kuanyan"), target.id) and data.card.type ~= Card.TypeEquip then
      local events = player.room.logic:getEventsOfScope(GameEvent.UseCard, 1, function(e)
        local use = e.data[1]
        return use.from == target.id and use.card.type == data.card.type
      end, Player.HistoryTurn)
      return #events > 0 and events[1].data[1] == data
    end
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:broadcastSkillInvoke("fk__kuanyan")
    room:notifySkillInvoked(player, "fk__kuanyan")
    player:drawCards(2, "fk__kuanyan")
    if not player:isNude() and not target.dead then
      local card = room:askForCard(player, 1, 1, true, "fk__kuanyan", false, ".", "#fk__kuanyan-ask:" .. target.id)
      room:moveCardTo(card, Card.PlayerHand, target, fk.ReasonGive, self.name, nil, false, player.id)
    end
    if not target.dead and not table.find(room.alive_players, function(p)
      return p.hp < target.hp
    end) then
      room:recover{
        who = target,
        recoverBy = player,
        skillName = "fk__kuanyan",
        num = 1,
      }
    end
  end,

  refresh_events = {fk.TurnStart},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(kuanyan)
  end,
  on_refresh = function(_, _, _, player)
    player.room:setPlayerMark(player, "fk__kuanyan", 0)
  end,
}
kuanyan:addRelatedSkill(kuanyan_delay)
lvboshe:addSkill(kuanyan)
local gufu = fk.CreateProhibitSkill{
  name = "fk__gufu",
  frequency = Skill.Compulsory,
  prohibit_use = function(self, player, card)
    if player:hasSkill(self) and table.find(Fk:currentRoom().alive_players, function(p)
      return p.phase ~= Player.NotActive and p:getMark("fk__kuanyan_target") ~= 0
    end) then
      local subcards = card:isVirtual() and card.subcards or {card.id}
      return #subcards > 0 and table.every(subcards, function(id)
        return table.contains(player:getCardIds(Player.Hand), id)
      end)
    end
  end,
  prohibit_response = function(self, player, card)
    if player:hasSkill(self) and table.find(Fk:currentRoom().alive_players, function(p)
      return p.phase ~= Player.NotActive and p:getMark("fk__kuanyan_target") ~= 0
    end) then
      local subcards = card:isVirtual() and card.subcards or {card.id}
      return #subcards > 0 and table.every(subcards, function(id)
        return table.contains(player:getCardIds(Player.Hand), id)
      end)
    end
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
  ["#kuanyan_delay"] = "款宴",
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
    player.room:setPlayerMark(player, "@fk__yicha-turn", table.concat(table.map(player:getMark("fk__yicha-turn"), Util.TranslateMapper)))
  end
}
guoyouzhi:addSkill(fk__zhongyu)
guoyouzhi:addSkill(fk__yicha)
Fk:loadTranslationTable{
  ['fk__guoyouzhi'] = '郭攸之',
  ['designer:fk__guoyouzhi'] = 's1134s',
  ["illustrator:fk__guoyouzhi"] = "三国志",
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
      room:obtainCard(player, get, false, fk.ReasonPrey, player.id, self.name, "@@fk__guici-inhand")
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
      self.cost_data = {cards = card, tos = {target.id}}
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cards = table.simpleClone(self.cost_data.cards)
    local draw = Fk:getCardById(cards[1]):getMark("@@fk__guici-inhand") > 0
    room:throwCard(cards, self.name, player, player)
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
  ["cv:fk__yingyang"] = "万事屋",
  ["illustrator:fk__yingyang"] = "网络",
  ["fk__guici"] = "瑰词",
  [":fk__guici"] = "转换技，锁定技，每轮开始时，你从牌堆中获得：阳：四张花色各不相同的牌；阴：三张类型各不相同的牌。",
  ["@@fk__guici-inhand"] = "瑰词",
  ["fk__beili"] = "悲离",
  [":fk__beili"] = "每当一名角色受到伤害后，你可以弃置一张牌，令其摸一张牌，若你以此法弃置了“瑰词”牌，你摸一张牌。",
  ["#fk__beili-discard"] = "悲离：你可弃一张牌，令 %dest 摸一张牌，若弃置“瑰词”牌，你摸一张牌。",

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
  ["cv:fk__liuyin"] = "某宝",
  ["illustrator:fk__liuyin"] = "网络",
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
    and table.every(player.player_cards[Player.Hand], function(id) return not player:prohibitDiscard(Fk:getCardById(id)) end)
  end,
  on_cost = function (self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, data, "#fk__guzhu-invoke::"..target.id..":"..data.card.name)
  end,
  on_use = function(self, event, target, player, data)
    player:throwAllCards("h")
    data.additionalEffect = (data.additionalEffect or 0) + 1
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
  ["#fk__zhangbu"] = "激浪迴环",
  ["designer:fk__zhangbu"] = "理塘王",
  ["cv:fk__zhangbu"] = "某宝",
  ["illustrator:fk__zhangbu"] = "啪啪三国",
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
    return target == player and player:hasSkill(self) and data.card.trueName == "slash" and
      #TargetGroup:getRealTargets(data.tos) == 1 and
      table.find(player.room.alive_players, function (p)
        return p:distanceTo(player) == 1
      end) and #player.room:getUseExtraTargets(data) > 0
  end,
  on_cost = function (self, event, target, player, data)
    local room = player.room
    local targets = room:getUseExtraTargets(data)
    local num = #table.filter(player.room.alive_players, function (p)
      return p:distanceTo(player) == 1
    end)
    local tos = room:askForChoosePlayers(player, targets, 1, num, "#fk__xiaorong:::" .. num, self.name, true)
    if #tos > 0 then
      self.cost_data = tos
      return true
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
    local room = player.room
    player:drawCards(2, self.name)
    room:addPlayerMark(player, "@fk__yiyong-turn")
    room:addPlayerMark(player, MarkEnum.SlashResidue .. "-turn")
  end
}
zhangwei:addSkill(fk__yiyong)
Fk:loadTranslationTable{
  ["fk__zhangwei"] = "张葳",
  ["illustrator:fk__zhangwei"] = "木美人",
  ["designer:fk__zhangwei"] = "郭攸之的设计修改者",
  ["fk__xiaorong"] = "骁戎",
  [":fk__xiaorong"] = "当你使用【杀】选择目标后，若目标角色数为1，你可以令至多X名其他角色也成为此【杀】的目标，然后若此【杀】的目标数大于你的体力值，你令此【杀】改为【决斗】（X为至你距离为1的角色）。",
  ["fk__yiyong"] = "义勇",
  [":fk__yiyong"] = "当你对手牌数大于你的角色造成伤害后，你可以摸两张牌，然后你本回合使用【杀】次数上限+1。",

  ["#fk__xiaorong"] = "骁戎：你可令至多%arg名其他角色成为此【杀】的目标",
  ["@fk__yiyong-turn"] = "义勇",
}

-- DIY5届： 李严、祖茂、曹洪、司马炎
-- 主催：理塘王

local liyans = General(extension, "fk__liyans", "shu", 3)
local duliang = fk.CreateActiveSkill{
  name = "fk__duliang",
  anim_type = "support",
  card_num = 0,
  target_num = 1,
  prompt = "#fk__duliang",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, to_select, selected)
    local flag = (to_select == Self.id) and "ej" or "hej"
    return #selected == 0 and #Fk:currentRoom():getPlayerById(to_select):getCardIds(flag) > 0
  end,
  on_use = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    local flag = (target == player) and "ej" or "hej"
    local get = room:askForCardChosen(player, target, flag, self.name)
    room:obtainCard(player, get, false, fk.ReasonPrey)
    if player.dead or target.dead then return end
    local choice = room:askForChoice(player, {"duliang_put", "duliang_draw"}, self.name)
    if choice == "duliang_put" then
      local put = room:askForCard(player, 1, 999, false, self.name, true, ".", "#fk__duliang-put")
      if #put == 0 then return end
      if #put > 1 then
        put = room:askForGuanxing(player, put, nil, {0,0}, self.name, true).top
      end
      room:moveCards({
        ids = table.reverse(put),
        from = player.id,
        toArea = Card.DrawPile,
        moveReason = fk.ReasonPut,
        skillName = self.name,
        proposer = player.id,
      })
      if not target.dead then
        local cards = room:getNCards(#put + 1)
        U.viewCards(target, cards, self.name)
        local types = {}
        for _, id in ipairs(put) do
          table.insertIfNeed(types, Fk:getCardById(id).type)
        end
        for i = #cards, 1, -1 do
          local id = cards[i]
          if not table.contains(types, Fk:getCardById(id).type) then
            table.insert(room.draw_pile, 1, id)
            table.remove(cards, i)
          end
        end
        if #cards > 0 then
          room:moveCardTo(cards, Card.PlayerHand, target, fk.ReasonPrey, self.name, "", false)
        end
        if not player.dead then
          player:drawCards(1, self.name)
        end
      end
    else
      room:addPlayerMark(target, "@duliang", 1)
    end
  end,
}
local duliang_trigger = fk.CreateTriggerSkill{
  name = "#fk__duliang_trigger",
  mute = true,
  events = {fk.DrawNCards},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:getMark("@duliang") > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data.n = data.n + player:getMark("@duliang")
    player.room:setPlayerMark(player, "@duliang", 0)
  end,
}
duliang:addRelatedSkill(duliang_trigger)
liyans:addSkill(duliang)
liyans:addSkill("fulin")
Fk:loadTranslationTable{
  ["fk__liyans"] = "李严",
  ["#fk__liyans"] = "矜风流务",
  ["designer:fk__liyans"] = "喜欢我曹金玉吗",
  ["illustrator:fk__liyans"] = "游漫美绘",

  ["fk__duliang"] = "督粮",
  [":fk__duliang"] = "出牌阶段限一次，你可以获得一名角色区域内的一张牌然后选择一项：1.将任意张手牌置于牌堆顶，若如此做，令其观看牌堆顶的X+1张牌并获得其中与你置于牌堆顶的牌含有的类型的牌，然后你摸一张牌；2.其下个摸牌阶段多摸一张牌（X为你置于牌堆顶的牌数）。",
  ["#fk__duliang"] = "督粮：获得一名角色区域内的一张牌",
  ["#fk__duliang_trigger"] = "督粮",
  ["duliang_put"] = "将任意张手牌置于牌堆顶",
  ["#fk__duliang-put"] = "督粮：将任意张手牌置于牌堆顶",

  ["$fk__duliang1"] = "运粮督战，以解前线之危。",
  ["$fk__duliang2"] = "不必催督，辎重稍后即至。",
  ["~fk__liyans"] = "权迷心智，吾，枉为人臣！",
}

local fk__zumao = General(extension, "fk__zumao", "wu", 4)
local fk__yinbing = fk.CreateTriggerSkill{
  name = "fk__yinbing",
  anim_type = "support",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and target == player and player.phase == Player.Finish
  end,
  on_cost = function(self, event, target, player, data)
    local tos = player.room:askForChoosePlayers(player, table.map(player.room:getOtherPlayers(player), Util.IdMapper), 1, 1, "#fk__yinbing-choose", self.name, true, true)
    if #tos > 0 then
      self.cost_data = tos[1]
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local mark = player:getTableMark(self.name)
    table.insertIfNeed(mark, self.cost_data)
    player.room:setPlayerMark(player, self.name, mark)
  end,

  refresh_events = {fk.TurnStart},
  can_refresh = function (self, event, target, player, data)
    return target == player and player:getMark(self.name) ~= 0
  end,
  on_refresh = function (self, event, target, player, data)
    player.room:setPlayerMark(player, self.name, 0)
  end,
}
local fk__yinbing_delay = fk.CreateTriggerSkill{
  name = "#fk__yinbing_delay",
  mute = true,
  events = {fk.TargetConfirming, fk.TargetConfirmed},
  can_trigger = function(self, event, target, player, data)
    if event == fk.TargetConfirming then
      return not target.dead and table.contains(player:getTableMark("fk__yinbing"), target.id) and (data.card.name == "duel" or data.card.trueName == "slash") and not table.contains(AimGroup:getAllTargets(data.tos), player.id) and not player.room:getPlayerById(data.from):isProhibited(player, data.card)
    elseif data.extra_data and table.contains((data.extra_data.fk__yinbing or {}), player.id) then
      local from = player.room:getPlayerById(data.from)
      return player:canPindian(from)
    end
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if event == fk.TargetConfirming then
      player:broadcastSkillInvoke("fk__yinbing", 3)
      AimGroup:addTargets(room, data, {player.id})
      AimGroup:cancelTarget(data, target.id)
      data.extra_data = data.extra_data or {}
      data.extra_data.fk__yinbing = data.extra_data.fk__yinbing or {}
      table.insertIfNeed(data.extra_data.fk__yinbing, player.id)
      return true
    elseif room:askForSkillInvoke(player, "fk__yinbing", nil, "#fk__yinbing-pindian:"..data.from) then
      player:pindian({room:getPlayerById(data.from)}, "fk__yinbing")
    end
  end,
}
fk__yinbing:addRelatedSkill(fk__yinbing_delay)
fk__zumao:addSkill(fk__yinbing)
local fk__juedi = fk.CreateTriggerSkill{
  name = "fk__juedi",
  anim_type = "defensive",
  events = {fk.TargetConfirming},
  frequency = Skill.Compulsory,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and data.card.is_damage_card
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data.extra_data = data.extra_data or {}
    data.extra_data.fk__juedi = data.extra_data.fk__juedi or {}
    data.extra_data.fk__juedi[tostring(player.id)] = data.extra_data.fk__juedi[tostring(player.id)] or {}
    for _, id in ipairs(player:drawCards(3, self.name)) do
      if table.contains(player.player_cards[Player.Hand], id) then
        room:setCardMark(Fk:getCardById(id), "@@fk__juedi-inhand", 1)
        table.insertIfNeed(data.extra_data.fk__juedi[tostring(player.id)], id)
      end
    end
  end,
}
local fk__juedi_delay = fk.CreateTriggerSkill{
  name = "#fk__juedi_delay",
  mute = true,
  events = {fk.CardUseFinished},
  frequency = Skill.Compulsory,
  can_trigger = function(self, event, target, player, data)
    return not player.dead and data.extra_data and data.extra_data.fk__juedi and data.extra_data.fk__juedi[tostring(player.id)]
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local mark = data.extra_data.fk__juedi[tostring(player.id)]
    local throw = table.filter(player.player_cards[Player.Hand], function (id)
      return table.contains(mark, id) and not player:prohibitDiscard(Fk:getCardById(id))
    end)
    if #throw > 0 then
      room:delay(500)
      room:throwCard(throw, self.name, player, player)
    end
  end,
}
fk__juedi:addRelatedSkill(fk__juedi_delay)
fk__zumao:addSkill(fk__juedi)
Fk:loadTranslationTable{
  ["fk__zumao"] = "祖茂",
  ["designer:fk__zumao"] = "少先队中央书记处第一书记",

  ["fk__yinbing"] = "引兵",
  [":fk__yinbing"] = "结束阶段，你可以秘密选择一名其他角色，直到你下回合开始，当其成为【杀】或【决斗】的目标时，转移给你。若如此做，你可以与此牌使用者拼点。",
  ["fk__juedi"] = "绝地",
  [":fk__juedi"] = "锁定技，当你成为伤害牌的目标时，你摸三张牌，此牌结算完成后，你弃置以此法获得的所有牌。",
  ["#fk__yinbing-choose"] = "引兵：选择一名其他角色；其成为【杀】或【决斗】的目标时转移给你",
  ["#fk__yinbing-pindian"] = "引兵：你可以与 %src 拼点",
  ["#fk__yinbing_delay"] = "引兵",
  ["@@fk__juedi-inhand"] = "绝地",
  ["#fk__juedi_delay"] = "绝地",

  ["$fk__yinbing1"] = "请脱赤帻，予某戴之！",
  ["$fk__yinbing2"] = "休想动主公一根寒毛！",
  ["$fk__yinbing3"] = "将军走此小道！",
  ["$fk__juedi1"] = "置之死地而后生！",
  ["$fk__juedi2"] = "主公安全，我可放心厮杀！",
  ["~fk__zumao"] = "护主周全，夙愿已偿。",
}

local caohong = General(extension, "fk__caohong", "wei", 4)

local yuanhu_active = fk.CreateActiveSkill{
  name = "fk__yuanhu_active",
  mute = true,
  card_num = 1,
  target_num = 1,
  card_filter = function(self, to_select, selected, targets)
    return #selected == 0 and Fk:getCardById(to_select).type == Card.TypeEquip
  end,
  interaction = function()
    return UI.ComboBox {choices = {"$Equip", "$Hand"} }
  end,
  target_filter = function(self, to_select, selected, cards)
    if #selected == 0 and #cards == 1 then
      local to = Fk:currentRoom():getPlayerById(to_select)
      if self.interaction.data == "$Equip" then
        return to:hasEmptyEquipSlot(Fk:getCardById(cards[1]).sub_type)
      else
        return not (table.contains(Self.player_cards[Player.Hand], cards[1]) and to_select == Self.id)
      end
    end
  end,
}
Fk:addSkill(yuanhu_active)
local yuanhu = fk.CreateTriggerSkill{
  name = "fk__yuanhu",
  anim_type = "support",
  events = {fk.EventPhaseStart, fk.AfterCardsMove},
  can_trigger = function(self, event, target, player, data)
    if event == fk.EventPhaseStart then
      return target == player and player:hasSkill(self) and player.phase == Player.Finish and not player:isNude()
    elseif player:hasSkill(self) then
      local use_id
      local e = player.room.logic:getCurrentEvent():findParent(GameEvent.UseCard)
      if e then
        if e.data[1].from == player.id and e.data[1].card.type == Card.TypeEquip then
          use_id = e.data[1].card:getEffectiveId()
        end
      end
      for _, move in ipairs(data) do
        if move.toArea == Card.PlayerEquip then
          if move.proposer == player.id or (#move.moveInfo == 1 and move.moveInfo[1].cardId == use_id) then
            return true
          end
        end
      end
    end
  end,
  on_trigger = function(self, event, target, player, data)
    if event == fk.EventPhaseStart then
      self:doCost(event, target, player, data)
    else
      local list = {}
      local use_id
      local e = player.room.logic:getCurrentEvent():findParent(GameEvent.UseCard)
      if e then
        if e.data[1].from == player.id and e.data[1].card.type == Card.TypeEquip then
          use_id = e.data[1].card:getEffectiveId()
        end
      end
      for _, move in ipairs(data) do
        if move.toArea == Card.PlayerEquip then
          for _, info in ipairs(move.moveInfo) do
            if move.proposer == player.id or info.cardId == use_id then
              table.insert(list, {to = player.room:getPlayerById(move.to), card = Fk:getCardById(info.cardId, true)})
            end
          end
        end
      end
      for _, dat in ipairs(list) do
        if not player:hasSkill(self) then break end
        self:doCost(event, dat.to, player, dat.card)
      end
    end
  end,
  on_cost = function(self, event, target, player, data)
    if event == fk.EventPhaseStart then
      local _,dat = player.room:askForUseActiveSkill(player, "fk__yuanhu_active", "#fk__yuanhu-put", true)
      if dat then
        self.cost_data = dat
        return true
      end
    else
      return true
    end
  end,
  on_use = function (self, event, target, player, data)
    local room = player.room
    if event == fk.EventPhaseStart then
      local dat = self.cost_data
      room:moveCardTo(dat.cards, dat.interaction == "$Equip" and Card.PlayerEquip or Card.PlayerHand, room:getPlayerById(dat.targets[1]), fk.ReasonPut, self.name, nil, true, player.id)
      room:delay(600)
    else
      local str = Fk:translate(":"..data.name)
      local _, start = str:find("技能</b>")
      if start then
        str = str:sub(start)
      end
      if string.find(str, "【杀】") and not player.dead then
        local targets = table.filter(room.alive_players, function (p) return not p:isAllNude() end)
        if #targets > 0 then
          local tos = room:askForChoosePlayers(player, table.map(targets, Util.IdMapper), 1, 1, "#fk__yuanhu-throw", self.name, false)
          local to = room:getPlayerById(tos[1])
          local card = room:askForCardChosen(player, to, "hej", self.name)
          room:throwCard(card, self.name, to, player)
        end
      end
      if string.find(str, "【闪】") and not player.dead and player:isWounded() then
        room:recover { num = 1, skillName = self.name, who = player, recoverBy = player }
      end
      if string.find(str, "伤害") and not player.dead then
        player:drawCards(1, self.name)
      end
      if string.find(str, "牌") and not target.dead then
        target:drawCards(1, self.name)
      end
      if string.find(str, "无效") and not target.dead then
        local tos = room:askForChoosePlayers(target, table.map(room.alive_players, Util.IdMapper), 1, 1, "#fk__yuanhu-damage", self.name, false)
        local to = room:getPlayerById(tos[1])
        room:damage { from = target, to = to, damage = 1, skillName = self.name }
      end
      if string.find(str, "距离") and not target.dead and target:isWounded() then
        room:recover { num = 1, skillName = self.name, who = target, recoverBy = player }
      end
    end
  end,
}
caohong:addSkill(yuanhu)

local fk__qianlin = fk.CreateTriggerSkill{
  name = "fk__qianlin",
  events = {fk.BeforeCardsMove},
  frequency = Skill.Compulsory,
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self) or player:isAllNude() or player == player.room.current then return end
    local ids = {}
    for _, move in ipairs(data) do
      if move.from == player.id then
        for _, info in ipairs(move.moveInfo) do
          if (info.fromArea >= 1 and info.fromArea <= 3) then
            table.insert(ids, info.cardId)
          end
        end
      end
    end
    if #ids == 0 then return end
    local e = player.room.logic:getCurrentEvent().parent
    if e and (e.event == GameEvent.UseCard or e.event == GameEvent.RespondCard) then
      if e.data[1].from == player.id then
        for _, id in ipairs(Card:getIdList(e.data[1].card)) do
          table.removeOne(ids, id)
        end
      end
    end
    if #ids > 0 then
      self.cost_data = ids
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local ids = self.cost_data
    local sub_types = {}
    for _, id in ipairs(ids) do
      if player.room:getCardArea(id) == Card.PlayerEquip then
        table.insert(sub_types, Fk:getCardById(id).sub_type)
      end
    end
    local throw_moves = {}
    for _, move in ipairs(data) do
      local move_info = table.simpleClone(move.moveInfo)
      if move.from == player.id then
        for _, info in ipairs(move.moveInfo) do
          if table.contains(ids, info.cardId) then
            table.removeOne(move_info, info)
          end
        end
      end
      local throw_info = {}
      if move.to == player.id and move.toArea == Card.PlayerEquip then -- 处理置换装备的情况
        for i = #move_info, 1, -1 do
          local info = move_info[i]
          if table.contains(sub_types, Fk:getCardById(info.cardId).sub_type) then
            table.insert(throw_info, table.remove(move_info, i))
          end
        end
      end
      move.moveInfo = move_info
      if #throw_info > 0 then
        local _move = table.simpleClone(move)
        _move.moveInfo = throw_info
        _move.moveReason = fk.ReasonPutIntoDiscardPile
        _move.to = nil
        _move.toArea = Card.DiscardPile
        table.insert(throw_moves, _move)
      end
    end
    if #throw_moves > 0 then
      table.insertTable(data, throw_moves)
    end
  end,
}
caohong:addSkill(fk__qianlin)

Fk:loadTranslationTable{
  ["fk__caohong"] = "曹洪",
  ["#fk__caohong"] = "献马救主",
  ["designer:fk__caohong"] = "千芬局",
  ["illustrator:fk__caohong"] = "鬼画府",

  ["fk__yuanhu"] = "援护",
  [":fk__yuanhu"] = "结束阶段，你可以将一张装备牌置入一名角色的装备区或手牌中。当你将一张装备牌置入一名角色的装备区时，若此牌包含以下内容："..
  "<br>【杀】，你弃置一名角色的区域里的一张牌；"..
  "<br>【闪】，你回复1点体力；"..
  "<br>伤害，你摸一张牌；"..
  "<br>无效，其对一名角色造成1点伤害；"..
  "<br>距离，其回复1点体力；"..
  "<br>牌，其摸一张牌。",
  ["fk__yuanhu_active"] = "援护",
  ["#fk__yuanhu-put"] = "援护：你可以将一张装备牌置入一名角色的装备区或手牌中",
  ["#fk__yuanhu-throw"] = "援护：弃置一名角色的区域里的一张牌",
  ["#fk__yuanhu-damage"] = "援护：对一名角色造成1点伤害",
  ["fk__qianlin"] = "悭吝",
  [":fk__qianlin"] = "锁定技，你的回合外，你区域内的牌只能通过你使用或打出的方式离开你的区域。",

  ["$fk__yuanhu1"] = "若无趁手兵器，不妨试试我这把！",
  ["$fk__yuanhu2"] = "此乃良驹，愿助将军日行千里！",
  ["~fk__caohong"] = "将军，多保重。",
}

local fk__simayan = General(extension, "fk__simayan", "jin", 4)

local fk__zhice = fk.CreateTriggerSkill{
  name = "fk__zhice",
  events = {fk.AfterCardsMove},
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if player:hasSkill(self) and player ~= player.room.current then
      for _, move in ipairs(data) do
        if move.to == player.id and move.toArea == Player.Hand then
          return true
        end
      end
    end
  end,
  on_cost = function (self, event, target, player, data)
    local room = player.room
    local targets = table.filter(room.alive_players, function (p) return p:getHandcardNum() <= player:getHandcardNum()
    and not p:isNude() end)
    local tos = room:askForChoosePlayers(player, table.map(targets, Util.IdMapper), 1, 1, "#fk__zhice-choose", self.name, true)
    if #tos > 0 then
      self.cost_data = tos[1]
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = room:getPlayerById(self.cost_data)
    local cards = room:askForDiscard(to, 1, 9999, true, self.name, true, ".|.|.|.|.|equip", "#fk__zhice-card")
    if not to.dead and #cards > 0 then
      to:drawCards(#cards, self.name)
    end
  end,
}
fk__simayan:addSkill(fk__zhice)

local fk__taikang = fk.CreateTriggerSkill{
  name = "fk__taikang",

  refresh_events = {fk.GameStart, fk.EventAcquireSkill, fk.EventLoseSkill, fk.Deathed, fk.AfterCardUseDeclared},
  can_refresh = function(self, event, target, player, data)
    if event == fk.GameStart then
      return player:hasSkill(self, true)
    elseif event == fk.EventAcquireSkill or event == fk.EventLoseSkill then
      return target == player and data == self and
        not table.find(player.room:getOtherPlayers(player), function(p) return p:hasSkill(self, true) end)
    elseif event == fk.AfterCardUseDeclared then
      return target == player and player:getMark("@@fk__taikang-turn") > 0 and data.card.type == Card.TypeBasic
    else
      return target == player and player:hasSkill(self, true, true) and
        not table.find(player.room:getOtherPlayers(player), function(p) return p:hasSkill(self, true) end)
    end
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    if event == fk.GameStart or event == fk.EventAcquireSkill then
      for _, p in ipairs(room:getOtherPlayers(player)) do
        room:handleAddLoseSkills(p, "fk__taikang_other&", nil, false, true)
      end
    elseif event == fk.AfterCardUseDeclared then
      room:setPlayerMark(player, "@@fk__taikang-turn", 0)
      data.additionalEffect = (data.additionalEffect or 0) + 1
    else
      for _, p in ipairs(room:getOtherPlayers(player, true, true)) do
        room:handleAddLoseSkills(p, "-fk__taikang_other&", nil, false, true)
      end
    end
  end,
}
local fk__taikang_other = fk.CreateActiveSkill{
  name = "fk__taikang_other&",
  mute = true,
  card_num = 1,
  target_num = 1,
  prompt = "#fk__taikang-prompt",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = function (self, to_select, selected)
    return #selected == 0
  end,
  target_filter = function (self, to_select, selected, cards)
    if #selected == 0 and to_select ~= Self.id and #cards == 1 then
      local to = Fk:currentRoom():getPlayerById(to_select)
      return to:hasSkill("fk__taikang") and not to:isNude()
    end
  end,
  on_use = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    local to = room:getPlayerById(effect.tos[1])
    to:broadcastSkillInvoke("fk__taikang")
    room:notifySkillInvoked(to, "fk__taikang", "drawcard")
    room:doIndicate(player.id, {to.id})
    room:recastCard(effect.cards, player, "fk__taikang")
    if to.dead or to:isNude() then return end
    local cards = room:askForCard(to, 1, 1, true, "fk__taikang", false, ".", "#fk__taikang-card")
    room:recastCard(cards, to, "fk__taikang")
    if to.dead or to:isNude() or player.dead then return end
    if #room:askForDiscard(to, 1, 1, true, "fk__taikang", true, ".", "#fk__taikang-cost:"..player.id) > 0 and not player.dead then
      room:setPlayerMark(player, "@@fk__taikang-turn", 1)
    end
  end,
}
Fk:addSkill(fk__taikang_other)
fk__simayan:addSkill(fk__taikang)

local fk__zongshe = fk.CreateTriggerSkill{
  name = "fk__zongshe$",
  anim_type = "drawcard",
  events = {fk.CardUsing},
  can_trigger = function(self, event, target, player, data)
    return target ~= player and player:hasSkill(self) and target.kingdom == "jin" and data.card.type == Card.TypeBasic
    and target:getHandcardNum() >= player:getHandcardNum()
  end,
  on_cost = function (self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, nil, "#fk__zongshe-invoke:"..target.id)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:doIndicate(player.id, {target.id})
    local tos = {player.id, target.id}
    room:sortPlayersByAction(tos)
    for _, pid in ipairs(tos) do
      if not room:getPlayerById(pid).dead then
        room:getPlayerById(pid):drawCards(1, self.name)
      end
    end
  end,
}
fk__simayan:addSkill(fk__zongshe)

Fk:loadTranslationTable{
  ["fk__simayan"] = "司马炎",
  ["#fk__simayan"] = "伟业的终主",
  ["designer:fk__simayan"] = "三无少女不会卖萌",
  ["cv:fk__simayan"] = "ZQ",
  ["illustrator:fk__simayan"] = "率土之滨",

  ["fk__zhice"] = "制策",
  [":fk__zhice"] = "当你于回合外获得牌时，你可以令一名手牌数不大于你的角色弃置任意张装备牌并摸等量牌。",
  ["#fk__zhice-choose"] = "制策：可以令一名手牌数不大于你的角色弃置任意张装备牌并摸等量牌",
  ["#fk__zhice-card"] = "制策：你可以弃置任意张装备牌并摸等量牌",

  ["fk__taikang"] = "太康",
  [":fk__taikang"] = "每名其他角色出牌阶段限一次，其可与你各重铸一张牌，然后你可以弃一张牌令其本回合使用的下一张基本牌额外结算一次。",
  ["#fk__taikang-card"] = "太康：请重铸一张牌",
  ["#fk__taikang-cost"] = "太康：你可以弃一张牌令 %src 本回合使用的下一张基本牌额外结算一次",
  ["fk__taikang_other&"] = "太康",
  [":fk__taikang_other&"] = "你可与拥有“太康”的其他角色各重铸一张牌，然后其可以弃一张牌令你本回合使用的下一张基本牌额外结算一次。",
  ["@@fk__taikang-turn"] = "太康",
  ["#fk__taikang-prompt"] = "太康：与拥有“太康”的其他角色各重铸一张牌",

  ["fk__zongshe"] = "纵奢",
  [":fk__zongshe"] = "主公技，其他晋势力角色使用基本牌时，若其手牌数不小于你，你可与其各摸一张牌。",
  ["#fk__zongshe-invoke"] = "纵奢：你可以与 %src 各摸一张牌",

  ["$fk__zhice1"] = "孙吴暴悖，三军奋锐，代朕行诛。",
  ["$fk__zhice2"] = "卷甲长驱，务使江东不复血刃。",
  ["$fk__taikang1"] = "炎虔奉皇运，钦承休命，以永答民望。",
  ["$fk__taikang2"] = "天序不可无统，人神不可旷主。",
  ["$fk__zongshe1"] = "骄代浮华？此等妄语，勿复言之。",
  ["$fk__zongshe2"] = "海内无事，朝露促促，卿等当与朕同此荣乐。",
  ["~fk__simayan"] = "人之无情，终至于此……",
  }

-- DIY6届：袁隗 王肃
-- 主催：理塘王

local yuanwei = General(extension, "fk__yuanwei", "qun", 5)

local chongwei = fk.CreateActiveSkill{
  name = "fk__chongwei",
  anim_type = "offensive",
  card_num = 0,
  target_num = 1,
  card_filter = Util.FalseFunc,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and Self.id ~= to_select
  end,
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  on_use = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    local to = room:getPlayerById(effect.tos[1])
    local all_choices = {"#fk__chongwei_change:"..player.id, "#fk__chongwei_hurt:"..player.id}
    local choices = {}
    if to.kingdom ~= player.kingdom then
      table.insert(choices, all_choices[1])
    end
    if #table.filter(player:getCardIds("he"), function(id) return not player:prohibitDiscard(id) end) > 1 then
      table.insert(choices, all_choices[2])
    end
    if #choices == 0 then return end
    local choice = room:askForChoice(to, choices, self.name, "", false, all_choices)
    if choice:startsWith("#fk__chongwei_change") then
      room:changeKingdom(to, player.kingdom, true)
      if player.dead or to.dead then return end
      to:drawCards(2, self.name)
      if player.dead or to.dead then return end
      local cards = to:getCardIds("he")
      if #cards > 2 then
        cards = room:askForCard(to, 2, 2, true, self.name, false, ".", "#fk__chongwei-give:"..player.id)
      end
      room:moveCardTo(cards, Player.Hand, player, fk.ReasonGive, self.name, nil, false, to.id)
    else
      local cards = room:askForDiscard(player, 2, 999, true, self.name, false, ".", "#fk__chongwei-card:"..to.id)
      if to.dead then return end
      if to:isNude() or room:askForChoice(player, {"#fk__chongwei_throw", "#fk__chongwei_damage"}, self.name) == "#fk__chongwei_damage"
      then
        room:doIndicate(player.id, {to.id})
        room:damage { from = player, to = to, damage = 1, skillName = self.name }
      else
        local x = math.min(#cards, #to:getCardIds("he"))
        local throw = room:askForCardsChosen(player, to, x, x, "he", self.name)
        room:throwCard(throw, self.name, to, player)
      end
    end
  end,
}
yuanwei:addSkill(chongwei)

local zuhuo = fk.CreateTriggerSkill{
  name = "fk__zuhuo",
  mute = true,
  frequency = Skill.Compulsory,
  events = {fk.TargetSpecifying, fk.DrawNCards},
  can_trigger = function(self, event, target, player, data)
    if event == fk.DrawNCards then
      return target == player and player:hasSkill(self)
    else
      return target ~= player and player:hasSkill(self) and player.kingdom == target.kingdom and player:getHandcardNum() > player.hp
      and data.card.is_damage_card and player.room:getPlayerById(data.to).seat == 1
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:broadcastSkillInvoke(self.name)
    if event == fk.DrawNCards then
      room:notifySkillInvoked(player, self.name, "drawcard")
      data.n = data.n + #table.filter(room.alive_players, function (p)
        return p.kingdom == player.kingdom
      end)
    else
      room:notifySkillInvoked(player, self.name, "negative")
      if not table.contains(AimGroup:getAllTargets(data.tos), player.id) and U.canTransferTarget (player, data, false) then
        AimGroup:addTargets(room, data, player.id)
        room:sendLog{ type = "#AddTargetsBySkill", from = data.from, to = {player.id}, arg = self.name, arg2 = data.card:toLogString() }
        room:doIndicate(data.from, {player.id})
      end
      data.extra_data = data.extra_data or {}
      data.extra_data.fk__zuhuo = data.extra_data.fk__zuhuo or {}
      table.insert(data.extra_data.fk__zuhuo, player.id)
    end
  end,
}
local zuhuo_delay = fk.CreateTriggerSkill{
  name = "#fk__zuhuo_delay",
  anim_type = "negative",
  frequency = Skill.Compulsory,
  events = {fk.DamageInflicted},
  can_trigger = function(self, event, target, player, data)
    if target == player then
      local e = player.room.logic:getCurrentEvent():findParent(GameEvent.CardEffect)
      if e then
        local use = e.data[1]
        return use.extra_data and table.contains(use.extra_data.fk__zuhuo or {}, player.id)
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    data.damage = data.damage + 1
  end,
}
zuhuo:addRelatedSkill(zuhuo_delay)
local zuhuo_maxcards = fk.CreateMaxCardsSkill{
  name = "#fk__zuhuo_maxcards",
  correct_func = function(self, player)
    if player:hasSkill(zuhuo) then
      return #table.filter(Fk:currentRoom().alive_players, function (p)
        return p.kingdom == player.kingdom
      end)
    end
  end,
}
zuhuo:addRelatedSkill(zuhuo_maxcards)
yuanwei:addSkill(zuhuo)

Fk:loadTranslationTable{
  ["fk__yuanwei"] = "袁隗",
  ["#fk__yuanwei"] = "福兮祸所伏",
  ["designer:fk__yuanwei"] = "蛋水",

  ["fk__chongwei"] = "崇位",
  [":fk__chongwei"] = "出牌阶段限一次，你可以令一名其他角色选择一项：变更势力至与你相同，然后摸两张牌并交给你两张牌；你弃置至少两张牌，然后弃置其等量牌或对其造成1点伤害。",
  ["#fk__chongwei_change"] = "变更势力与 %src 相同，摸两张牌并交给其两张牌",
  ["#fk__chongwei_hurt"] = "%src 弃置至少两张牌，弃置你等量牌或对你造成1点伤害",
  ["#fk__chongwei-card"] = "崇位：弃置至少两张牌，然后弃置 %src 等量牌或对其造成1点伤害",
  ["#fk__chongwei-give"] = "崇位：请交给 %src 两张牌",
  ["#fk__chongwei_throw"] = "弃置其等量牌",
  ["#fk__chongwei_damage"] = "对其造成1点伤害",

  ["fk__zuhuo"] = "族祸",
  [":fk__zuhuo"] = "锁定技，你的额定摸牌数和手牌上限+X（X为与你势力相同的存活角色数）；与你势力相同的其他角色使用伤害牌指定一号位为目标时，若你的手牌数大于体力值，你也成为此牌目标且你受到此牌造成的伤害+1。",
  ["#fk__zuhuo_delay"] = "族祸",
}

local wangsu = General(extension, "fk__wangsu", "wei", 3)
wangsu.subkingdom = "jin"

local fk__jingzhu = fk.CreateTriggerSkill{
  name = "fk__jingzhu",
  anim_type = "control",
  derived_piles = "fk__jingzhu",
  frequency = Skill.Compulsory,
  events = {fk.CardUseFinished},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and U.isPureCard(data.card)
    and data.tos and table.contains(TargetGroup:getRealTargets(data.tos), player.id)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local all_choices = {"#fk__jingzhu_put:::"..data.card.name,"#fk__jingzhu_watch"}
    local choices = {}
    if room:getCardArea(data.card) == Card.Processing or table.contains(player:getCardIds("e"), data.card:getEffectiveId()) then
      table.insert(choices, all_choices[1])
    end
    local targets = table.filter(room.alive_players, function (p)
      return player ~= p and not p:isKongcheng()
    end)
    if #targets > 0 and #player:getPile(self.name) > 0 then
      table.insert(choices, all_choices[2])
    end
    if #choices == 0 then return end
    local choice = room:askForChoice(player, choices, self.name, nil, false, all_choices)
    if choice == all_choices[1] then
      player:addToPile(self.name, data.card, true, self.name)
    else
      local tos = room:askForChoosePlayers(player, table.map(targets, Util.IdMapper), 1, 1, "#fk__jingzhu-choose", self.name, false)
      local to = room:getPlayerById(tos[1])
      local result = room:askForPoxi(player, "fk__jingzhu", {
        { self.name, player:getPile(self.name) },
        { to.general, to:getCardIds("h") },
      }, nil, true)
      if #result == 2 then
        room:moveCards({
          ids = {result[1]},
          from = player.id,
          toArea = Card.DiscardPile,
          moveReason = fk.ReasonPutIntoDiscardPile,
          skillName = self.name,
          proposer = player.id,
        })
        local cid = result[2]
        if not player.dead and table.contains(to:getCardIds("h"), cid) then
          U.askForUseRealCard(room, player, {cid}, ".", self.name, "#fk__jingzhu-use:::"..Fk:getCardById(cid):toLogString(),
          {expand_pile = {cid}}, false, false)
        end
      end
    end
  end,
}
wangsu:addSkill(fk__jingzhu)

Fk:addPoxiMethod{
  name = "fk__jingzhu",
  card_filter = function(to_select, selected, data)
    if data == nil then return false end
    if #selected == 0 then
      return table.contains(data[1][2], to_select)
    elseif #selected == 1 then
      if not table.contains(data[1][2], selected[1]) then return false end
      local card = Fk:getCardById(to_select)
      local first = Fk:getCardById(selected[1])
      return Self:canUse(card, {bypass_times = true}) and card.trueName ~= first.trueName and card.type == first.type
    end
  end,
  feasible = function(selected, data, extra_data)
    if data == nil or #selected ~= 2 then return false end
    return #table.filter(selected, function (id)
      return table.contains(data[1][2], id)
    end) == 1
  end,
  prompt = "#fk__jingzhu-card",
  default_choice = function ()
    return {}
  end,
}

local fk__yuanxue = fk.CreateTriggerSkill{
  name = "fk__yuanxue",
  events = {fk.TargetSpecified},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and U.isPureCard(data.card)
    and U.isOnlyTarget(player.room:getPlayerById(data.to), data, event) and not player.room:getPlayerById(data.to).dead
    and table.find(player:getPile("fk__jingzhu"), function (id)
      return Fk:getCardById(id).type == data.card.type
    end)
  end,
  on_cost = function (self, event, target, player, data)
    local room = player.room
    local to = room:getPlayerById(data.to)
    local ids = table.filter(U.getUniversalCards(room, "bt"), function (id)
      local card = Fk:getCardById(id)
      if card.skill:getMinTargetNum() > 1 then
        return false
      elseif card.skill:getMinTargetNum() == 0 then
        if to ~= player and not card.multiple_targets then return false end
      end
      return player:canUseTo(card, to, {bypass_distances = true, bypass_times = true})
    end)
    local cards = room:askForCard(player, 1, 1, false, self.name, true, tostring(Exppattern{ id = ids }),
    "#fk__yuanxue-use::"..to.id..":"..data.card:getTypeString(), ids)
    if #cards > 0 then
      self.cost_data = Fk:getCardById(cards[1]).name
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local pile = table.filter(player:getPile("fk__jingzhu"), function (id)
      return Fk:getCardById(id).type == data.card.type
    end)
    if #pile == 0 then return end
    if #pile > 1 then
      pile = {room:askForCardChosen(player, player, {card_data = { { "fk__jingzhu", pile } }}, self.name, "#fk__yuanxue-remove")}
    end
    room:moveCards({
      ids = pile,
      from = player.id,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPutIntoDiscardPile,
      skillName = self.name,
      proposer = player.id,
    })
    room:useVirtualCard(self.cost_data, nil, player, room:getPlayerById(data.to), self.name, true)
  end,
}
wangsu:addSkill(fk__yuanxue)

local fk__weilun = fk.CreateTriggerSkill{
  name = "fk__weilun",
  anim_type = "control",
  frequency = Skill.Compulsory,
  events = {fk.AfterCardsMove},
  can_trigger = function(self, event, target, player, data)
    if player:hasSkill(self) then
      for _, move in ipairs(data) do
        if move.toArea ~= Card.Void then
          for _, info in ipairs(move.moveInfo) do
            if info.fromArea == Card.PlayerSpecial then
              return true
            end
          end
        end
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local x = player:usedSkillTimes(self.name, Player.HistoryTurn)
    room:setPlayerMark(player, "@fk__weilun-turn", x)
    local skills = Fk.generals[player.general]:getSkillNameList(true)
    if player.deputyGeneral ~= "" then
      table.insertTable(skills, Fk.generals[player.deputyGeneral]:getSkillNameList(true))
    end
    local skill = skills[x]
    if skill then
      local mark = player:getTableMark("fk__weilun_skill-turn")
      table.insert(mark, skill)
      room:setPlayerMark(player, "fk__weilun_skill-turn", mark)
    end
    player:drawCards(1, self.name)
  end,
}
local fk__weilun_invalidity = fk.CreateInvaliditySkill {
  name = "#fk__weilun_invalidity",
  invalidity_func = function(self, player, skill)
    return table.contains(player:getTableMark("fk__weilun_skill-turn"), skill.name)
  end
}
fk__weilun:addRelatedSkill(fk__weilun_invalidity)
wangsu:addSkill(fk__weilun)

Fk:loadTranslationTable{
  ["fk__wangsu"] = "王肃",
  ["#fk__wangsu"] = "由文而济",
  ["designer:fk__wangsu"] = "三无少女不会卖萌",
  ["cv:fk__wangsu"] = "万事屋",
  ["illustrator:fk__wangsu"] = "率土之滨",


  ["fk__jingzhu"] = "经注",
  [":fk__jingzhu"] = "锁定技，每当实体牌对你结算结束后，你须选择一项：1.将此牌置于你武将牌上，称为“经注”；2.观看一名其他角色手牌，然后你可以移去一张“经注”并使用其手牌中一张与移去的“经注”相同类型、不同牌名的牌。",
  ["#fk__jingzhu_put"] = "将%arg置入“经注”",
  ["#fk__jingzhu_watch"] = "观看一名角色手牌",
  ["#fk__jingzhu-choose"] = "经注：观看一名其他角色手牌",
  ["#fk__jingzhu-card"] = "经注：移去一张“经注”并选择一张与之同类异名的牌",
  ["#fk__jingzhu-use"] = "经注：请使用 %arg",

  ["fk__yuanxue"] = "远斈",
  [":fk__yuanxue"] = "当你使用的实体牌指定唯一目标后，你可以移去一张与此牌类别相同的“经注”，视为对该角色使用一张任意基本牌或普通锦囊牌。",
  ["#fk__yuanxue-use"] = "远斈：可移去一张 %arg“经注”，视为对 %dest 使用一张任意基本牌或普通锦囊牌",
  ["#fk__yuanxue-remove"] = "远斈：移去一张“经注”",

  ["fk__weilun"] = "伪论",
  [":fk__weilun"] = "锁定技，当有牌移入游戏后，你摸一张牌并令武将牌上第X个技能本回合失效（X为你本回合此技能已发动的次数）。",
  ["@fk__weilun-turn"] = "伪论",

  ["$fk__jingzhu1"] = "夫子没而微言绝，后学当治经明义。",
  ["$fk__jingzhu2"] = "秦火重而群经毁，我辈须彰灼圣训。",
  ["$fk__yuanxue1"] = "君子于学，当穷书籍、厚德行。",
  ["$fk__yuanxue2"] = "雕凿诗礼，钻之弥坚；追述先圣，行之弥远。",
  ["$fk__weilun1"] = "康成公之注，发明大义而已。",
  ["$fk__weilun2"] = "诸子聚讼莫决者，必以圣言为定论。",
  ["~fk__wangsu"] = "一愧先圣，二愧国家，三愧……仁义。",}


return extension
