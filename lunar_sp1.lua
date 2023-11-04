local extension = Package("lunar_sp1")
extension.extensionName = "lunar"

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
    room:broadcastSkillInvoke("fk__kuanyan")
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
    local cids = table.slice(room.draw_pile, 1, (5 - x) + 1)
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
    local ret = room:askForGuanxing(player, cids, nil, nil, self.name, true, { "Top", "pile_discard" }).bottom
    room:moveCardTo(ret, Card.DiscardPile, nil, fk.ReasonDiscard, self.name, nil, true)
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
    if player:hasSkill(self.name, true) then
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
    '并弃置其中任意张牌。（X为本回合内进入弃牌堆内的牌的总花色数）',
  ['#fk__yicha-invoke'] = '益察：你可观看牌堆顶 %arg 张牌并进行操作',
  --['#fk__yicha-choice'] = '益察：牌堆顶的 %arg 牌分别是 %arg2 , 请选择一种操作',
  --['#fk__yicha-cDiscard'] = '弃置任意张牌',
  --['#fk__yicha-cExchange'] = '用一张牌与其中一张牌交换',
  --['#fk__yicha-cExchange-choose'] = '益察：你须选择一张牌',
  --['#fk__yicha-cGuan'] = '以任意顺序置于牌堆顶',
  ['@fk__yicha-turn'] = '益察',
}

return extension
