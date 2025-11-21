SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_LOC_RULES_200001_10             */
/* Creation Date: 12-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into LOC target table             */
/*                                                                      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 =  '0'  Ignore LOC              */
/*                           @c_InParm1 =  '1'  LOC update is allow     */
/*           Loc Hostwhcode  @c_InParm2 =  '0'  Ignore loc hostwhcode   */
/*                           @c_InParm2 =  '1'  Check loc hostwhcode    */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.2                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 12-Jan-2022  GHChan    1.1   Initial                                 */
/* 27-Oct-2022  WLChooi   1.2   WMS-21026 - Add extra fields (WL01)     */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_LOC_RULES_200001_10] (
   @b_Debug       INT            = 0
 , @n_BatchNo     INT            = 0
 , @n_Flag        INT            = 0
 , @c_SubRuleJson NVARCHAR(MAX)
 , @c_STGTBL      NVARCHAR(250)  = ''
 , @c_POSTTBL     NVARCHAR(250)  = ''
 , @c_UniqKeyCol  NVARCHAR(1000) = ''
 , @c_Username    NVARCHAR(128)  = ''
 , @b_Success     INT            = 0 OUTPUT
 , @n_ErrNo       INT            = 0 OUTPUT
 , @c_ErrMsg      NVARCHAR(250)  = '' OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON;
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_WARNINGS OFF;

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT;

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60);
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @n_RowRefNo  INT
         , @c_Storerkey NVARCHAR(15)
         , @c_Loc       NVARCHAR(15)
         , @c_ttlMsg    NVARCHAR(250);

   SELECT @c_InParm1 = InParm1
        , @c_InParm2 = InParm2
        , @c_InParm3 = InParm3
        , @c_InParm4 = InParm4
        , @c_InParm5 = InParm5
   FROM
      OPENJSON(@c_SubRuleJson)
      WITH (
      SPName NVARCHAR(300) '$.SubRuleSP'
    , InParm1 NVARCHAR(60) '$.InParm1'
    , InParm2 NVARCHAR(60) '$.InParm2'
    , InParm3 NVARCHAR(60) '$.InParm3'
    , InParm4 NVARCHAR(60) '$.InParm4'
    , InParm5 NVARCHAR(60) '$.InParm5'
      )
   WHERE SPName = OBJECT_NAME(@@PROCID);

   SET @n_StartTCnt = @@TRANCOUNT;

   DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
        , ISNULL(RTRIM(Loc), '')
   FROM dbo.SCE_DL_LOC_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1';

   OPEN C_HDR;
   FETCH NEXT FROM C_HDR
   INTO @n_RowRefNo
      , @c_Loc;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      BEGIN TRAN;

      IF EXISTS (
      SELECT 1
      FROM dbo.V_LOC WITH (NOLOCK)
      WHERE Loc = @c_Loc
      )
      BEGIN
         IF @c_InParm1 = '1'
         BEGIN
            UPDATE L WITH (ROWLOCK)
            SET L.Loc = STG.Loc
              , L.[Cube] = ISNULL(STG.[Cube], L.[Cube])
              , L.[Length] = ISNULL(STG.[Length], L.[Length])
              , L.Width = ISNULL(STG.Width, L.Width)
              , L.Height = ISNULL(STG.Height, L.Height)
              , L.LocationType = ISNULL(STG.LocationType, L.LocationType)
              , L.LocationFlag = ISNULL(STG.LocationFlag, L.LocationFlag)
              , L.LocationHandling = ISNULL(STG.LocationHandling, L.LocationHandling)
              , L.LocationCategory = ISNULL(STG.LocationCategory, L.LocationCategory)
              , L.LogicalLocation = ISNULL(STG.LogicalLocation, L.LogicalLocation)
              , L.CubicCapacity = ISNULL(STG.CubicCapacity, L.CubicCapacity)
              , L.WeightCapacity = ISNULL(STG.WeightCapacity, L.WeightCapacity)
              , L.[Status] = ISNULL(STG.[Status], L.[Status])
              , L.LoseId = ISNULL(STG.LoseId, L.LoseId)
              , L.Facility = STG.Facility
              , L.ABC = ISNULL(STG.ABC, L.ABC)
              , L.PickZone = ISNULL(STG.PickZone, L.PickZone)
              , L.PutawayZone = STG.PutawayZone
              , L.SectionKey = ISNULL(STG.SectionKey, L.SectionKey)
              , L.PickMethod = ISNULL(STG.PickMethod, L.PickMethod)
              , L.CommingleSku = ISNULL(STG.CommingleSku, L.CommingleSku)
              , L.CommingleLot = ISNULL(STG.CommingleLot, L.CommingleLot)
              , L.LocLevel = ISNULL(STG.LocLevel, L.LocLevel)
              , L.Xcoord = ISNULL(STG.Xcoord, L.Xcoord)
              , L.Ycoord = ISNULL(STG.Ycoord, L.Ycoord)
              , L.Zcoord = ISNULL(STG.Zcoord, L.Zcoord)
              , L.MaxPallet = ISNULL(STG.MaxPallet, L.MaxPallet)
              , L.LocAisle = ISNULL(STG.LocAisle, L.LocAisle)
              , L.HOSTWHCODE = CASE WHEN @c_InParm2 = '0' THEN ISNULL(STG.HOSTWHCODE, L.HOSTWHCODE)
                                    ELSE ISNULL(STG.HOSTWHCODE, '')
                               END
              , L.CCLogicalLoc = ISNULL(STG.CCLogicalLoc, L.CCLogicalLoc)
              , L.ChargingPallet = ISNULL(STG.ChargingPallet, L.ChargingPallet)
              , L.LastCycleCount = ISNULL(STG.LastCycleCount, L.LastCycleCount)
              , L.CycleCountFrequency = ISNULL(STG.CycleCountFrequency, L.CycleCountFrequency)
              , L.LoseUCC = ISNULL(STG.LoseUCC, L.LoseUCC)
              , L.NoMixLottable01 = ISNULL(STG.NoMixLottable01, L.NoMixLottable01)
              , L.NoMixLottable02 = ISNULL(STG.NoMixLottable02, L.NoMixLottable02)
              , L.NoMixLottable03 = ISNULL(STG.NoMixLottable03, L.NoMixLottable03)
              , L.NoMixLottable04 = ISNULL(STG.NoMixLottable04, L.NoMixLottable04)
              , L.NoMixLottable05 = ISNULL(STG.NoMixLottable05, L.NoMixLottable05)
              , L.NoMixLottable06 = ISNULL(STG.NoMixLottable06, L.NoMixLottable06)
              , L.NoMixLottable07 = ISNULL(STG.NoMixLottable07, L.NoMixLottable07)
              , L.NoMixLottable08 = ISNULL(STG.NoMixLottable08, L.NoMixLottable08)
              , L.NoMixLottable09 = ISNULL(STG.NoMixLottable09, L.NoMixLottable09)
              , L.NoMixLottable10 = ISNULL(STG.NoMixLottable10, L.NoMixLottable10)
              , L.NoMixLottable11 = ISNULL(STG.NoMixLottable11, L.NoMixLottable11)
              , L.NoMixLottable12 = ISNULL(STG.NoMixLottable12, L.NoMixLottable12)
              , L.NoMixLottable13 = ISNULL(STG.NoMixLottable13, L.NoMixLottable13)
              , L.NoMixLottable14 = ISNULL(STG.NoMixLottable14, L.NoMixLottable14)
              , L.NoMixLottable15 = ISNULL(STG.NoMixLottable15, L.NoMixLottable15)
              , L.LocBay = ISNULL(STG.LocBay, L.LocBay)
              , L.PALogicalLoc = ISNULL(STG.PALogicalLoc, L.PALogicalLoc)
              , L.Score = ISNULL(STG.Score, L.Score)
              , L.LocationRoom = ISNULL(STG.LocationRoom, L.LocationRoom)
              , L.LocationGroup = ISNULL(STG.LocationGroup, L.LocationGroup)
              , L.[Floor] = ISNULL(STG.[Floor], L.[Floor])
              , L.Descr = ISNULL(STG.Descr, L.Descr)
              , L.EditWho = @c_Username
              , L.EditDate = GETDATE()
              , L.LocCheckDigit = ISNULL(STG.LocCheckDigit, L.LocCheckDigit)   --WL01
              , L.CycleCounter = ISNULL(STG.CycleCounter, L.CycleCounter)   --WL01
              , L.MaxCarton = ISNULL(STG.MaxCarton, L.MaxCarton)   --WL01
              , L.MaxSKU = ISNULL(STG.MaxSKU, L.MaxSKU)   --WL01
            FROM dbo.SCE_DL_LOC_STG STG WITH (NOLOCK)
            JOIN dbo.LOC            L
            ON L.Loc = STG.Loc
            WHERE STG.RowRefNo = @n_RowRefNo;
         END;
      END;
      ELSE
      BEGIN
         INSERT INTO dbo.LOC
         (
            Loc
          , [Cube]
          , [Length]
          , Width
          , Height
          , LocationType
          , LocationFlag
          , LocationHandling
          , LocationCategory
          , LogicalLocation
          , CubicCapacity
          , WeightCapacity
          , [Status]
          , LoseId
          , Facility
          , ABC
          , PickZone
          , PutawayZone
          , SectionKey
          , PickMethod
          , CommingleSku
          , CommingleLot
          , LocLevel
          , Xcoord
          , Ycoord
          , Zcoord
          , MaxPallet
          , LocAisle
          , HOSTWHCODE
          , CCLogicalLoc
          , ChargingPallet
          , LastCycleCount
          , CycleCountFrequency
          , LoseUCC
          , NoMixLottable01
          , NoMixLottable02
          , NoMixLottable03
          , NoMixLottable04
          , NoMixLottable05
          , NoMixLottable06
          , NoMixLottable07
          , NoMixLottable08
          , NoMixLottable09
          , NoMixLottable10
          , NoMixLottable11
          , NoMixLottable12
          , NoMixLottable13
          , NoMixLottable14
          , NoMixLottable15
          , LocBay
          , AddWho
          , EditWho
          , PALogicalLoc
          , Score
          , LocationRoom
          , LocationGroup
          , [Floor]
          , Descr
          , LocCheckDigit   --WL01
          , CycleCounter   --WL01
          , MaxCarton   --WL01
          , MaxSKU   --WL01
         )
         SELECT @c_Loc
              , ISNULL([Cube], 0)
              , ISNULL(Length, 0)
              , ISNULL(Width, 0)
              , ISNULL(Height, 0)
              , ISNULL(LocationType, 'OTHER')
              , ISNULL(LocationFlag, 'NONE')
              , ISNULL(LocationHandling, '1')
              , ISNULL(LocationCategory, 'OTHER')
              , ISNULL(LogicalLocation, '')
              , ISNULL(CubicCapacity, 0)
              , ISNULL(WeightCapacity, 0)
              , ISNULL(Status, 'OK')
              , ISNULL(LoseId, 0)
              , Facility
              , ISNULL(ABC, 'B')
              , ISNULL(PickZone, '')
              , PutawayZone
              , ISNULL(SectionKey, 'FACILITY')
              , ISNULL(PickMethod, '')
              , ISNULL(CommingleSku, '1')
              , ISNULL(CommingleLot, '1')
              , ISNULL(LocLevel, 0)
              , ISNULL(Xcoord, 0)
              , ISNULL(Ycoord, 0)
              , ISNULL(Zcoord, 0)
              , ISNULL(MaxPallet, 0)
              , ISNULL(LocAisle, '')
              , CASE WHEN @c_InParm2 = '0' THEN HOSTWHCODE
                     ELSE ISNULL(HOSTWHCODE, '')
                END
              , ISNULL(CCLogicalLoc, '')
              , ISNULL(ChargingPallet, 0)
              , ISNULL(LastCycleCount, '')
              , ISNULL(CycleCountFrequency, 0)
              , ISNULL(LoseUCC, '')
              , ISNULL(NoMixLottable01, '')
              , ISNULL(NoMixLottable02, '')
              , ISNULL(NoMixLottable03, '')
              , ISNULL(NoMixLottable04, '')
              , ISNULL(NoMixLottable05, '')
              , ISNULL(NoMixLottable06, '')
              , ISNULL(NoMixLottable07, '')
              , ISNULL(NoMixLottable08, '')
              , ISNULL(NoMixLottable09, '')
              , ISNULL(NoMixLottable10, '')
              , ISNULL(NoMixLottable11, '')
              , ISNULL(NoMixLottable12, '')
              , ISNULL(NoMixLottable13, '')
              , ISNULL(NoMixLottable14, '')
              , ISNULL(NoMixLottable15, '')
              , ISNULL(LocBay, '')
              , @c_Username
              , @c_Username
              , ISNULL(STG.PALogicalLoc, '')
              , ISNULL(Score, 0)
              , ISNULL(LocationRoom, '')
              , ISNULL(LocationGroup, '')
              , ISNULL([Floor], '')
              , ISNULL(Descr, '')
              , ISNULL(LocCheckDigit, '')   --WL01
              , ISNULL(CycleCounter, 0)   --WL01
              , ISNULL(MaxCarton, 0)   --WL01
              , ISNULL(MaxSKU, 0)   --WL01
         FROM dbo.SCE_DL_LOC_STG STG WITH (NOLOCK)
         WHERE STG.RowRefNo = @n_RowRefNo;
      END;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      UPDATE dbo.SCE_DL_LOC_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      WHILE @@TRANCOUNT > 0
      COMMIT TRAN;

      FETCH NEXT FROM C_HDR
      INTO @n_RowRefNo
         , @c_Loc;

   END;

   CLOSE C_HDR;
   DEALLOCATE C_HDR;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_LOC_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
   END;

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN TRAN;

   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0;
      IF @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN;
      END;
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN;
         END;
      END;
   END;
   ELSE
   BEGIN
      SET @b_Success = 1;
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN;
      END;
   END;
END;

GO