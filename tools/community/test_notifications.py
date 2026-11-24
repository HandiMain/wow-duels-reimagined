from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def read(p): return (ROOT/p).read_text(encoding="utf-8")
class NotificationTests(unittest.TestCase):
    def test_shared_card_and_effects_channel(self):
        u=read("UI/Notifications.lua")
        for token in ('pcall(PlaySoundFile,SOUND,"SFX")','ns.Motion','ns.Presence.Subscribe','ns.DuelDetection.Subscribe',
                      'GetNotificationAnchor','if #queue>=8','PREVIEW: Addon update','Settings.SnoozeUpdate',
                      'ns.Footer.ShowReleaseLink','NotificationArt.png'):
            self.assertIn(token,u)
        for token in ('SetCVar(','SendAddonMessage(','RecordLocalObservation(','OnUpdate','"Master"'):
            self.assertNotIn(token,u)
        self.assertTrue((ROOT/"Media/Sounds/Notifications/General.mp3").is_file())
        self.assertTrue((ROOT/"Media/Skin/NotificationArt.png").is_file())
    def test_release_evidence_and_development_gate(self):
        u=read("Core/UpdateNotices.lua")
        self.assertIn('if n>=2',u)
        self.assertIn('if not mine or not latest',u)
        self.assertIn('development build; preview only',u)
        self.assertNotIn('PatchNotesData',u)
        self.assertNotIn('Comm.Send',u)

    def test_visual_atlas_and_shared_button_sampling(self):
        import struct
        data=(ROOT/"Media/Skin/NotificationArt.png").read_bytes()
        self.assertEqual(struct.unpack(">II",data[16:24]),(1024,512))
        u=read("UI/Notifications.lua")
        self.assertIn('8,8,792,356',u)
        self.assertIn('8,372,792,66',u)
        self.assertIn('tx:SetTexture(ART)',u)
        self.assertIn('local ax=gold and 320 or 8',u)
        self.assertIn('32,14,88,20,820,112,192,44',u)
        self.assertIn('290,14,88,20,820,168,192,44',u)
        self.assertIn('118,12,174,24',u)
        self.assertIn('448.5/512,503.5/512',u)
        self.assertNotIn('218.25/256',u)

    def test_rank_promotion_preview_contract(self):
        u=read("UI/Notifications.lua")
        for token in ('ns.CompetitiveUI.CreateRankEmblem','ns.SeasonRules','PREVIEW: Rank promotion',
                      'pcall(PlaySoundFile,PROMOTION_SOUND,"SFX")','C_Timer.NewTimer',
                      'CancelExpiry(true)','preview:promotion','function N.PreviewPromotion()'):
            self.assertIn(token,u)
        self.assertIn('Preview rank promotion',read("UI/Options.lua"))
        self.assertIn('message=="notify rank"',read("Core/Commands.lua"))
        self.assertTrue((ROOT/"Media/Skin/RankPromotionArt.tga").is_file())
