-- Enemy loader (placeholder)
local Chaser = require 'src.enemy.chaser'
local Reclaimer = require 'src.enemy.reclaimer'
local Jammer = require 'src.enemy.jammer'
local Base = require 'src.enemy.base'
local GuardianBreaker = require 'src.enemy.guardian_breaker'
local ReclaimerBoss = require('src.enemy.reclaimer_boss')
local Infester = require('src.enemy.infester')
local Phaser = require('src.enemy.phaser')
local Splitter = require('src.enemy.splitter')
local Teleporter = require('src.enemy.teleporter')

return {
    Chaser = Chaser,
    Reclaimer = Reclaimer,
    Jammer = Jammer,
    Base = Base,
    GuardianBreaker = GuardianBreaker,
    ReclaimerBoss = ReclaimerBoss,
    Infester = Infester,
    Phaser = Phaser,
    Splitter = Splitter,
    Teleporter = Teleporter,
}
