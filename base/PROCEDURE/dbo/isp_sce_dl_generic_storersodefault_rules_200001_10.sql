SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_STORERSODEFAULT_RULES_200001_10 */
/* Creation Date: 29-Sep-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23690 - Perform insert into STORERSODEFAULT target table*/
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Allow Update                                */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 29-Sep-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_STORERSODEFAULT_RULES_200001_10] (
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
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60)
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @n_RowRefNo     INT
         , @c_ttlMsg       NVARCHAR(250)
         , @c_Storerkey    NVARCHAR(15)

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
   WHERE SPName = OBJECT_NAME(@@PROCID)

   BEGIN TRANSACTION

   DECLARE C_INS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
        , ISNULL(TRIM(Storerkey),'')
   FROM dbo.SCE_DL_STORERSODEFAULT_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1'

   OPEN C_INS
   FETCH NEXT FROM C_INS
   INTO @n_RowRefNo
      , @c_Storerkey

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''
      
      IF EXISTS ( SELECT 1
                  FROM STORERSODEFAULT SOD (NOLOCK)
                  WHERE SOD.Storerkey = @c_Storerkey)
      BEGIN
         IF @c_InParm1 = '1'
         BEGIN
            --Update
            BEGIN TRANSACTION

            UPDATE SOD WITH (ROWLOCK)
            SET SOD.BillTo        = CASE WHEN ISNULL(STG.BillTo, '') = '' THEN SOD.BillTo WHEN STG.BillTo = '$$' THEN '' ELSE STG.BillTo END
              , SOD.OrderType     = CASE WHEN ISNULL(STG.OrderType, '') = '' THEN SOD.OrderType WHEN STG.OrderType = '$$' THEN '' ELSE STG.OrderType END
              , SOD.Priority      = CASE WHEN ISNULL(STG.Priority     , '') = '' THEN SOD.Priority      WHEN STG.Priority      = '$$' THEN '' ELSE STG.Priority      END
              , SOD.Route         = CASE WHEN ISNULL(STG.Route        , '') = '' THEN SOD.Route         WHEN STG.Route         = '$$' THEN '' ELSE STG.Route         END
              , SOD.Door          = CASE WHEN ISNULL(STG.Door         , '') = '' THEN SOD.Door          WHEN STG.Door          = '$$' THEN '' ELSE STG.Door          END
              , SOD.Stop          = CASE WHEN ISNULL(STG.Stop         , '') = '' THEN SOD.Stop          WHEN STG.Stop          = '$$' THEN '' ELSE STG.Stop          END
              , SOD.Destination   = CASE WHEN ISNULL(STG.Destination  , '') = '' THEN SOD.Destination   WHEN STG.Destination   = '$$' THEN '' ELSE STG.Destination   END
              , SOD.Terms         = CASE WHEN ISNULL(STG.Terms        , '') = '' THEN SOD.Terms         WHEN STG.Terms         = '$$' THEN '' ELSE STG.Terms         END
              , SOD.DeliveryPlace = CASE WHEN ISNULL(STG.DeliveryPlace, '') = '' THEN SOD.DeliveryPlace WHEN STG.DeliveryPlace = '$$' THEN '' ELSE STG.DeliveryPlace END
              , SOD.xDockLane     = CASE WHEN ISNULL(STG.xDockLane , '') = '' THEN SOD.xDockLane  WHEN STG.xDockLane  = '$$' THEN '' ELSE STG.xDockLane  END
              , SOD.XDockRoute    = CASE WHEN ISNULL(STG.XDockRoute, '') = '' THEN SOD.XDockRoute WHEN STG.XDockRoute = '$$' THEN '' ELSE STG.XDockRoute END
              , SOD.XDockSTOP     = CASE WHEN ISNULL(STG.XDockSTOP , '') = '' THEN SOD.XDockSTOP  WHEN STG.XDockSTOP  = '$$' THEN '' ELSE STG.XDockSTOP  END
              , SOD.CutOffHour    = CASE WHEN ISNULL(STG.CutOffHour, '') = '' THEN SOD.CutOffHour WHEN STG.CutOffHour = '$$' THEN '' ELSE STG.CutOffHour END   
              , SOD.CutOffMin     = CASE WHEN ISNULL(STG.CutOffMin,  '') = '' THEN SOD.CutOffMin  WHEN STG.CutOffMin  = '$$' THEN '' ELSE STG.CutOffMin END
              , SOD.DeliveryTerm  = CASE WHEN ISNULL(STG.DeliveryTerm, 0) = 0 THEN SOD.DeliveryTerm WHEN STG.DeliveryTerm = -1 THEN 0 ELSE STG.DeliveryTerm END
              , SOD.Mon = CASE WHEN ISNULL(STG.Mon, '') = '' THEN SOD.Mon WHEN STG.Mon = '$' THEN '' ELSE STG.Mon END
              , SOD.Tue = CASE WHEN ISNULL(STG.Tue, '') = '' THEN SOD.Tue WHEN STG.Tue = '$' THEN '' ELSE STG.Tue END
              , SOD.Wed = CASE WHEN ISNULL(STG.Wed, '') = '' THEN SOD.Wed WHEN STG.Wed = '$' THEN '' ELSE STG.Wed END
              , SOD.Thu = CASE WHEN ISNULL(STG.Thu, '') = '' THEN SOD.Thu WHEN STG.Thu = '$' THEN '' ELSE STG.Thu END
              , SOD.Fri = CASE WHEN ISNULL(STG.Fri, '') = '' THEN SOD.Fri WHEN STG.Fri = '$' THEN '' ELSE STG.Fri END
              , SOD.Sat = CASE WHEN ISNULL(STG.Sat, '') = '' THEN SOD.Sat WHEN STG.Sat = '$' THEN '' ELSE STG.Sat END
              , SOD.Sun = CASE WHEN ISNULL(STG.Sun, '') = '' THEN SOD.Sun WHEN STG.Sun = '$' THEN '' ELSE STG.Sun END
              , SOD.HolidayKey  = CASE WHEN ISNULL(STG.HolidayKey , '') = '' THEN SOD.HolidayKey  WHEN STG.HolidayKey  = '$$' THEN '' ELSE STG.HolidayKey  END
              , SOD.ScheduleKey = CASE WHEN ISNULL(STG.ScheduleKey, '') = '' THEN SOD.ScheduleKey WHEN STG.ScheduleKey = '$$' THEN '' ELSE STG.ScheduleKey END
              , SOD.AddrOvrFlag = CASE WHEN ISNULL(STG.AddrOvrFlag, '') = '' THEN SOD.AddrOvrFlag WHEN STG.AddrOvrFlag = '$'  THEN '' ELSE STG.AddrOvrFlag END
              , SOD.EditWho = SUSER_SNAME()
              , SOD.EditDate = GETDATE()
            FROM SCE_DL_STORERSODEFAULT_STG STG (NOLOCK)
            JOIN StorerSODefault SOD ON SOD.Storerkey = STG.Storerkey
            WHERE STG.RowRefNo = @n_RowRefNo
            AND STG_BatchNo = @n_BatchNo
            AND STG_Status  = '1'
         END
         ELSE
         BEGIN
            UPDATE dbo.SCE_DL_STORERSODEFAULT_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error: Storerkey: ' + TRIM(@c_StorerKey) + ' already exists in STORERSODEFAULT table.'
            WHERE RowRefNo = @n_RowRefNo
            AND STG_BatchNo = @n_BatchNo
            AND STG_Status  = '1'

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END

            GOTO NEXT_ITEM
         END
      END
      ELSE
      BEGIN
         --Insert
         BEGIN TRANSACTION

         INSERT INTO StorerSODefault ( StorerKey, BillTo, OrderType, [Priority], [Route], Door, [Stop], Destination, Terms
                                     , DeliveryPlace, xDockLane, XDockRoute, XDockSTOP
                                     , CutOffHour, CutOffMin, DeliveryTerm
                                     , Mon, Tue, Wed, Thu
                                     , Fri, Sat, Sun
                                     , HolidayKey, ScheduleKey, AddrOvrFlag
                                     , AddWho, AddDate )
         SELECT StorerKey, BillTo, OrderType, [Priority], [Route], Door, [Stop], Destination, Terms
              , DeliveryPlace, ISNULL(xDockLane, ''), XDockRoute, XDockSTOP
              , ISNULL(CutOffHour, '00'), ISNULL(CutOffMin, '00'), ISNULL(DeliveryTerm, 0)
              , ISNULL(Mon, '0'), ISNULL(Tue, '0'), ISNULL(Wed, '0'), ISNULL(Thu, '0')
              , ISNULL(Fri, '0'), ISNULL(Sat, '0'), ISNULL(Sun, '0')
              , ISNULL(HolidayKey, '0'), ISNULL(ScheduleKey, ''), ISNULL(AddrOvrFlag, '')
              , AddWho, AddDate
         FROM SCE_DL_STORERSODEFAULT_STG STG (NOLOCK)
         WHERE STG.RowRefNo = @n_RowRefNo
         AND STG_BatchNo = @n_BatchNo
         AND STG_Status  = '1'

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END

      UPDATE dbo.SCE_DL_STORERSODEFAULT_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         ROLLBACK TRAN
         GOTO QUIT
      END

      NEXT_ITEM:

      FETCH NEXT FROM C_INS
      INTO @n_RowRefNo
         , @c_Storerkey
   END

   CLOSE C_INS
   DEALLOCATE C_INS

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_STORERSODEFAULT_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
   END

   IF @n_Continue = 1
   BEGIN
      SET @b_Success = 1
   END
   ELSE
   BEGIN
      SET @b_Success = 0
   END
END
GO