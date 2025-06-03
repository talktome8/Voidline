-- Enemy loader (placeholder)
local Chaser = require 'src.enemy.chaser'
local Reclaimer = require 'src.enemy.reclaimer'
local Jammer = require 'src.enemy.jammer'
local Base = require 'src.enemy.base'
local GuardianBreaker = require 'src.enemy.guardian_breaker'
local ReclaimerBoss = require('src.enemy.reclaimer_boss')

return {
    Chaser = Chaser,
    Reclaimer = Reclaimer,
    Jammer = Jammer,
    Base = Base,
    GuardianBreaker = GuardianBreaker,
    ReclaimerBoss = ReclaimerBoss,
}
