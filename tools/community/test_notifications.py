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

    def test_original_promotion_sound_and_lifetime(self):
        import hashlib
        sound=(ROOT/"Media/Sounds/Notifications/RankPromotion.mp3").read_bytes()
        self.assertEqual(len(sound),257280)
        self.assertEqual(hashlib.sha1(b"blob "+str(len(sound)).encode()+b"\0"+sound).hexdigest(),
                         "80476e35942961d0dd732b78d81fc4637239c927")
        u=read("UI/Notifications.lua")
        self.assertIn("local PROMOTION_SOUND_SECONDS=8.04",u)
        self.assertIn("PROMOTION_SOUND_SECONDS+2",u)

    def test_achievement_art_audio_and_shared_bridge(self):
        import hashlib,struct
        def blob(data):
            return hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest()
        sound=(ROOT/"Media/Sounds/Notifications/Achievement.mp3").read_bytes()
        self.assertEqual(blob(sound),"ef355c8d9ba8721fad79df44a03f581bfdb0be81")
        art=(ROOT/"Media/Skin/AchievementNotificationArt.png").read_bytes()
        self.assertEqual(blob(art),"3fe53bb5c77bccfda64ae9c0ef253ff4526be1df")
        self.assertEqual(struct.unpack(">II",art[16:24]),(1024,512))
        u=read("UI/Notifications.lua")
        for token in ('ACHIEVEMENT_SOUND_SECONDS=6.426094','ACHIEVEMENT_SOUND_SECONDS+2',
                      'pcall(PlaySoundFile,ACHIEVEMENT_SOUND,"SFX")','ns.AchievementUI.PaintAchievementIcon',
                      'function N.CheckAchievements()','function N.ResetAchievementPreview()'):
            self.assertIn(token,u)
        self.assertIn('message=="notify achievement"',read("Core/Commands.lua"))
        self.assertIn('Preview achievement notification',read("UI/Options.lua"))

    def test_achievement_points_share_wreath_center(self):
        u=read("UI/Notifications.lua")
        self.assertIn('achPoints=AchLabel("",20,C.pale,326,58,61,28)',u)
        self.assertIn('achPointsLabel=AchLabel("Points",11,C.pale,326,83,61,18)',u)

    def test_warning_compact_art_and_preview(self):
        import hashlib,struct
        art=(ROOT/"Media/Skin/WarningNotificationArt.png").read_bytes()
        self.assertEqual(struct.unpack(">II",art[16:24]),(1024,256))
        self.assertEqual(hashlib.sha1(b"blob "+str(len(art)).encode()+b"\0"+art).hexdigest(),"d40e0f76abfdc885ea5fb71321cc625611f18003")
        u=read("UI/Notifications.lua")
        for token in ('WARN_WIDTH,WARN_BODY,WARN_EXTENSION=320,72,14',
                      'pcall(PlaySoundFile,WARNING_SOUND,"SFX")',
                      'local WARNING_SOUND_SECONDS=nil','function N.PreviewWarning()',
                      'id="preview:warning",kind="warning",preview=true',
                      'Visible(warning,warned);Visible(warningConnector,warned);Visible(warningClose,warned)'):
            self.assertIn(token,u)
        self.assertIn('message=="notify warning"',read("Core/Commands.lua"))
        self.assertIn('Preview warning notification',read("UI/Options.lua"))
