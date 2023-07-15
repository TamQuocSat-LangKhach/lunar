local extension = Package("lunar_sp1")
extension.extensionName = "lunar"

Fk:loadTranslationTable{
  lunar_sp1 = "新月杀专属",
  fk = "新月",
}

-- 新月杀第一届DIY选拔： 吕伯奢，郭攸之
local lvboshe = General(extension, "fk__lvboshe", "qun", 3)
local kuanyanTrig = fk.CreateTriggerSkill{
  name = "#fk__kuanyan",
  mute = true,
  events = {fk.CardUsing},
  can_trigger = function(self, event, target, player, data)
    if player:hasSkill(self.name) and player:getMark("fk__kuanyan") == target.id then
      return player:getMark("fk__kuanyan" .. data.card.type) == 0 and
        (data.card.type == Card.TypeBasic or data.card.type == Card.TypeTrick)
    end
  end,
  on_cost = function() return true end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:broadcastSkillInvoke("fk__kuanyan")
    room:notifySkillInvoked(player, "fk__kuanyan")
    room:addPlayerMark(player, "fk__kuanyan" .. data.card.type, 1)

    player:drawCards(1, "fk__kuanyan")
    local card = room:askForCard(player, 1, 1, true, "fk__kuanyan", false, ".", "#fk__kuanyan-ask:" .. target.id)
    room:obtainCard(target.id, card[1], false, fk.ReasonGive)

    if not table.find(room:getOtherPlayers(target), function(p)
      return p.hp >= target.hp
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
    local current = table.find(Fk:currentRoom().alive_players, function(p)
      return p.phase ~= Player.NotActive
    end)
    if not current then return false end
    return current:getMark("fk__kuanyan_target") ~= 0
  end,
  prohibit_response = function(self, player, card)
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
  ["fk__kuanyan"] = "款宴",
  [":fk__kuanyan"] = "出牌阶段限一次，你可以弃置一张牌并选择一名其他角色，" ..
    "直至你的下个回合开始，该角色每回合使用第一张基本牌和锦囊牌后，" ..
    "你摸一张牌并交给其一张牌，若其体力值为全场唯一最低，其回复一点体力。",
  ["#fk__kuanyan-ask"] = "款宴: 请交给 %src 一张牌",
  ["fk__gufu"] = "故负",
  [":fk__gufu"] = "锁定技，在成为过〖款宴〗目标的角色回合内，你不能使用或打出手牌。",
}

return extension
