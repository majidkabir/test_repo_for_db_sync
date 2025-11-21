SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_STORER_RULES_200001_10          */
/* Creation Date: 10-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into Storer target table          */
/*                                                                      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 =  '0'  Ignore existing Storer  */
/*                           @c_InParm1 =  '1'  Update is allow         */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-May-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_STORER_RULES_200001_10] (
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

   DECLARE @c_Storerkey  NVARCHAR(15)
         , @n_RowRefNo   INT
         , @n_FoundExist INT
         , @n_ActionFlag INT
         , @c_ttlMsg     NVARCHAR(250);

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

   IF @c_InParm1 = '1'
   BEGIN

      BEGIN TRANSACTION;

      DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
           , RTRIM(StorerKey)
      FROM dbo.SCE_DL_STORER_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1';

      OPEN C_HDR;
      FETCH NEXT FROM C_HDR
      INTO @n_RowRefNo
         , @c_Storerkey;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @n_FoundExist = 0;
         SELECT @n_FoundExist = 1
         FROM dbo.V_STORER WITH (NOLOCK)
         WHERE StorerKey = @c_Storerkey;

         IF @c_InParm1 = '1'
         BEGIN
            IF @n_FoundExist = 1
            BEGIN
               SET @n_ActionFlag = 1; -- UPDATE
            END;
            ELSE
            BEGIN
               SET @n_ActionFlag = 0; -- INSERT
            END;
         END;
         ELSE IF @c_InParm1 = '0'
         BEGIN
            IF @n_FoundExist = 1
            BEGIN
               UPDATE dbo.SCE_DL_STORER_STG WITH (ROWLOCK)
               SET STG_Status = '5'
                 , STG_ErrMsg = 'Error:StorerKey already exists'
               WHERE STG_BatchNo = @n_BatchNo
               AND   STG_Status    = '1'
               AND   Storerkey     = @c_Storerkey;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  ROLLBACK TRAN;
                  GOTO QUIT;
               END;
               GOTO NEXTITEM;
            END;
            ELSE
            BEGIN
               SET @n_ActionFlag = 0; -- INSERT
            END;
         END;

         IF @n_ActionFlag = 1
         BEGIN

            UPDATE S WITH (ROWLOCK)
            SET S.type = ISNULL(STG.type, '2')
              , S.Company = CASE WHEN ISNULL(STG.Company, '') = '' THEN S.Company
                                 ELSE STG.Company
                            END
              , S.VAT = CASE WHEN ISNULL(STG.VAT, '') = '' THEN S.VAT
                             ELSE STG.VAT
                        END
              , S.Address1 = CASE WHEN ISNULL(STG.Address1, '') = '' THEN S.Address1
                                  ELSE STG.Address1
                             END
              , S.Address2 = CASE WHEN ISNULL(STG.Address2, '') = '' THEN S.Address2
                                  ELSE STG.Address2
                             END
              , S.Address3 = CASE WHEN ISNULL(STG.Address3, '') = '' THEN S.Address3
                                  ELSE STG.Address3
                             END
              , S.Address4 = CASE WHEN ISNULL(STG.Address4, '') = '' THEN S.Address4
                                  ELSE STG.Address4
                             END
              , S.City = CASE WHEN ISNULL(STG.City, '') = '' THEN S.City
                              ELSE STG.City
                         END
              , S.State = CASE WHEN ISNULL(STG.State, '') = '' THEN S.State
                               ELSE STG.State
                          END
              , S.Zip = CASE WHEN ISNULL(STG.Zip, '') = '' THEN S.Zip
                             ELSE STG.Zip
                        END
              , S.Country = CASE WHEN ISNULL(STG.Country, '') = '' THEN S.Country
                                 ELSE STG.Country
                            END
              , S.ISOCntryCode = CASE WHEN ISNULL(STG.ISOCntryCode, '') = '' THEN S.ISOCntryCode
                                      ELSE STG.ISOCntryCode
                                 END
              , S.Contact1 = CASE WHEN ISNULL(STG.Contact1, '') = '' THEN S.Contact1
                                  ELSE STG.Contact1
                             END
              , S.Contact2 = CASE WHEN ISNULL(STG.Contact2, '') = '' THEN S.Contact2
                                  ELSE STG.Contact2
                             END
              , S.Phone1 = CASE WHEN ISNULL(STG.Phone1, '') = '' THEN S.Phone1
                                ELSE STG.Phone1
                           END
              , S.Phone2 = CASE WHEN ISNULL(STG.Phone2, '') = '' THEN S.Phone2
                                ELSE STG.Phone2
                           END
              , S.Fax1 = CASE WHEN ISNULL(STG.Fax1, '') = '' THEN S.Fax1
                              ELSE STG.Fax1
                         END
              , S.Fax2 = CASE WHEN ISNULL(STG.Fax2, '') = '' THEN S.Fax1
                              ELSE STG.Fax2
                         END
              , S.Email1 = CASE WHEN ISNULL(STG.Email1, '') = '' THEN S.Email1
                                ELSE STG.Email1
                           END
              , S.Email2 = CASE WHEN ISNULL(STG.Email2, '') = '' THEN S.Email2
                                ELSE STG.Email2
                           END
              , S.B_contact1 = CASE WHEN ISNULL(STG.B_contact1, '') = '' THEN S.B_contact1
                                    ELSE STG.B_contact1
                               END
              , S.B_Contact2 = CASE WHEN ISNULL(STG.B_Contact2, '') = '' THEN S.B_Contact2
                                    ELSE STG.B_Contact2
                               END
              , S.B_Company = CASE WHEN ISNULL(STG.B_Company, '') = '' THEN S.B_Company
                                   ELSE STG.B_Company
                              END
              , S.B_Address1 = CASE WHEN ISNULL(STG.B_Address1, '') = '' THEN S.B_Address1
                                    ELSE STG.B_Address1
                               END
              , S.B_Address2 = CASE WHEN ISNULL(STG.B_Address2, '') = '' THEN S.B_Address2
                                    ELSE STG.B_Address2
                               END
              , S.B_Address3 = CASE WHEN ISNULL(STG.B_Address3, '') = '' THEN S.B_Address3
                                    ELSE STG.B_Address3
                               END
              , S.B_Address4 = CASE WHEN ISNULL(STG.B_Address4, '') = '' THEN S.B_Address4
                                    ELSE STG.B_Address4
                               END
              , S.B_City = CASE WHEN ISNULL(STG.B_City, '') = '' THEN S.B_City
                                ELSE STG.B_City
                           END
              , S.B_State = CASE WHEN ISNULL(STG.B_State, '') = '' THEN S.B_State
                                 ELSE STG.B_State
                            END
              , S.B_Zip = CASE WHEN ISNULL(STG.B_Zip, '') = '' THEN S.B_Zip
                               ELSE STG.B_Zip
                          END
              , S.B_Country = CASE WHEN ISNULL(STG.B_Country, '') = '' THEN S.B_Country
                                   ELSE STG.B_Country
                              END
              , S.B_ISOCntryCode = CASE WHEN ISNULL(STG.B_ISOCntryCode, '') = '' THEN S.B_ISOCntryCode
                                        ELSE STG.B_ISOCntryCode
                                   END
              , S.B_Phone1 = CASE WHEN ISNULL(STG.B_Phone1, '') = '' THEN S.B_Phone1
                                  ELSE STG.B_Phone1
                             END
              , S.B_Phone2 = CASE WHEN ISNULL(STG.B_Phone2, '') = '' THEN S.B_Phone2
                                  ELSE STG.B_Phone2
                             END
              , S.B_Fax1 = CASE WHEN ISNULL(STG.B_Fax1, '') = '' THEN S.B_Fax1
                                ELSE STG.B_Fax1
                           END
              , S.B_Fax2 = CASE WHEN ISNULL(STG.B_Fax2, '') = '' THEN S.B_Fax2
                                ELSE STG.B_Fax2
                           END
              , S.Notes1 = CASE WHEN ISNULL(CAST(STG.Notes1 AS NVARCHAR(255)), '') = '' THEN CAST(S.Notes1 AS NVARCHAR(255))
                                ELSE CAST(STG.Notes1 AS NVARCHAR(255))
                           END
              , S.Notes2 = CASE WHEN ISNULL(CAST(STG.Notes2 AS NVARCHAR(255)), '') = '' THEN CAST(S.Notes2 AS NVARCHAR(255))
                                ELSE CAST(STG.Notes2 AS NVARCHAR(255))
                           END
              , S.CreditLimit = CASE WHEN ISNULL(STG.CreditLimit, '0') = '0' THEN S.CreditLimit
                                     ELSE STG.CreditLimit
                                END
              , S.CartonGroup = CASE WHEN ISNULL(STG.CartonGroup, '') = '' THEN S.CartonGroup
                                     ELSE STG.CartonGroup
                                END
              , S.PickCode = CASE WHEN ISNULL(STG.PickCode, 'NSPFIFO') = 'NSPFIFO' THEN S.PickCode
                                  ELSE STG.PickCode
                             END
              , S.CreatePATaskOnRFReceipt = ISNULL(STG.CreatePATaskOnRFReceipt, '0')
              , S.CalculatePutAwayLocation = ISNULL(STG.CalculatePutAwayLocation, '2')
              , S.Status = CASE WHEN ISNULL(STG.Status, '') = '' THEN S.Status
                                ELSE STG.Status
                           END
              , S.MinShelfLife = CASE WHEN ISNULL(STG.MinShelfLife, 0) = 0 THEN S.MinShelfLife
                                      ELSE STG.MinShelfLife
                                 END
              , S.Logo = CASE WHEN ISNULL(STG.Logo, '') = '' THEN S.Logo
                              ELSE STG.Logo
                         END
              , S.Facility = CASE WHEN ISNULL(STG.Facility, '') = '' THEN S.Facility
                                  ELSE STG.Facility
                             END
              , S.LabelPrice = CASE WHEN ISNULL(STG.LabelPrice, '') = '' THEN S.LabelPrice
                                    ELSE STG.LabelPrice
                               END
              , S.TolerancePctg = CASE WHEN ISNULL(STG.TolerancePctg, '') = '' THEN S.TolerancePctg
                                       ELSE STG.TolerancePctg
                                  END
              , S.Pallet = CASE WHEN ISNULL(STG.Pallet, '') = '' THEN S.Pallet
                                ELSE STG.Pallet
                           END
              , S.ConsigneeFor = CASE WHEN ISNULL(STG.ConsigneeFor, '') = '' THEN S.ConsigneeFor
                                      ELSE STG.ConsigneeFor
                                 END
              , S.SUSR1 = CASE WHEN ISNULL(STG.SUSR1, '') = '' THEN S.SUSR1
                               ELSE ISNULL(STG.SUSR1, '')
                          END
              , S.SUSR2 = CASE WHEN ISNULL(STG.SUSR2, '') = '' THEN S.SUSR2
                               ELSE ISNULL(STG.SUSR2, '')
                          END
              , S.SUSR3 = CASE WHEN ISNULL(STG.SUSR3, '') = '' THEN S.SUSR3
                               ELSE ISNULL(STG.SUSR3, '')
                          END
              , S.SUSR4 = CASE WHEN ISNULL(STG.SUSR4, '') = '' THEN S.SUSR4
                               ELSE ISNULL(STG.SUSR4, '')
                          END
              , S.SUSR5 = CASE WHEN ISNULL(STG.SUSR5, '') = '' THEN S.SUSR5
                               ELSE ISNULL(STG.SUSR5, '')
                          END
              , S.Secondary = CASE WHEN ISNULL(STG.Secondary, '') = '' THEN S.Secondary
                                   ELSE STG.Secondary
                              END
              , S.XDockStrategykey = CASE WHEN ISNULL(STG.XDockStrategykey, 'STD') = 'STD' THEN S.XDockStrategykey
                                          ELSE STG.XDockStrategykey
                                     END
              , S.StrategyKey = CASE WHEN ISNULL(STG.StrategyKey, '') = '' THEN S.StrategyKey
                                     ELSE STG.StrategyKey
                                END
              , S.CtnPickQty = CASE WHEN ISNULL(STG.CtnPickQty, 0) = 0 THEN S.CtnPickQty
                                    ELSE STG.CtnPickQty
                               END
              , CustomerGroupCode = CASE WHEN ISNULL(STG.CustomerGroupCode, '') = '' THEN S.CustomerGroupCode
                                         ELSE STG.CustomerGroupCode
                                    END
              , S.CustomerGroupName = CASE WHEN ISNULL(STG.CustomerGroupName, '') = '' THEN S.CustomerGroupName
                                           ELSE STG.CustomerGroupName
                                      END
              , S.MarketSegment = CASE WHEN ISNULL(STG.MarketSegment, '') = '' THEN S.MarketSegment
                                       ELSE STG.MarketSegment
                                  END
              , S.EditDate = GETDATE()
              , S.EditWho = @c_Username
            FROM dbo.STORER            S
            JOIN dbo.SCE_DL_STORER_STG STG WITH (NOLOCK)
            ON STG.StorerKey = S.StorerKey
            WHERE STG.RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;
         END;
         ELSE IF @n_ActionFlag = 0
         BEGIN
            INSERT INTO dbo.STORER
            (
               StorerKey
             , type
             , Company
             , VAT
             , Address1
             , Address2
             , Address3
             , Address4
             , City
             , State
             , Zip
             , Country
             , ISOCntryCode
             , Contact1
             , Contact2
             , Phone1
             , Phone2
             , Fax1
             , Fax2
             , Email1
             , Email2
             , B_contact1
             , B_Contact2
             , B_Company
             , B_Address1
             , B_Address2
             , B_Address3
             , B_Address4
             , B_City
             , B_State
             , B_Zip
             , B_Country
             , B_ISOCntryCode
             , B_Phone1
             , B_Phone2
             , B_Fax1
             , B_Fax2
             , Notes1
             , Notes2
             , CreditLimit
             , CartonGroup
             , PickCode
             , CreatePATaskOnRFReceipt
             , CalculatePutAwayLocation
             , Status
             , TrafficCop
             , ArchiveCop
             , MinShelfLife
             , Logo
             , Facility
             , LabelPrice
             , TolerancePctg
             , Pallet
             , ConsigneeFor
             , SUSR1
             , SUSR2
             , SUSR3
             , SUSR4
             , SUSR5
             , Secondary
             , XDockStrategykey
             , StrategyKey
             , CtnPickQty
             , CustomerGroupCode
             , CustomerGroupName
             , MarketSegment
             , ABCLogic
             , ABCPeriod
             , WorkDayPerWeek
             , PercentA
             , PercentB
             , PickFaceMethod
             , ProductGrouping
             , PickLocFlag
             , AddWho
             , EditWho
            )
            SELECT @c_Storerkey
                 , ISNULL(type, '2')
                 , Company
                 , VAT
                 , Address1
                 , Address2
                 , Address3
                 , Address4
                 , City
                 , State
                 , Zip
                 , Country
                 , ISOCntryCode
                 , Contact1
                 , Contact2
                 , Phone1
                 , Phone2
                 , Fax1
                 , Fax2
                 , Email1
                 , Email2
                 , B_contact1
                 , B_Contact2
                 , B_Company
                 , B_Address1
                 , B_Address2
                 , B_Address3
                 , B_Address4
                 , B_City
                 , B_State
                 , B_Zip
                 , B_Country
                 , B_ISOCntryCode
                 , B_Phone1
                 , B_Phone2
                 , B_Fax1
                 , B_Fax2
                 , CAST(Notes1 AS NVARCHAR(255))
                 , CAST(Notes2 AS NVARCHAR(255))
                 , ISNULL(CreditLimit, '0')
                 , ISNULL(CartonGroup, 'STD')
                 , ISNULL(PickCode, 'NSPFIFO')
                 , ISNULL(CreatePATaskOnRFReceipt, '0')
                 , ISNULL(CalculatePutAwayLocation, '2')
                 , Status
                 , TrafficCop
                 , ArchiveCop
                 , ISNULL(MinShelfLife, 0)
                 , ISNULL(Logo, '')
                 , Facility
                 , LabelPrice
                 , TolerancePctg
                 , Pallet
                 , ConsigneeFor
                 , ISNULL(SUSR1, '')
                 , ISNULL(SUSR2, '')
                 , ISNULL(SUSR3, '')
                 , ISNULL(SUSR4, '')
                 , ISNULL(SUSR5, '')
                 , ISNULL(Secondary, '')
                 , ISNULL(XDockStrategykey, 'STD')
                 , ISNULL(StrategyKey, '')
                 , ISNULL(CtnPickQty, 0)
                 , ISNULL(CustomerGroupCode, '')
                 , ISNULL(CustomerGroupName, '')
                 , ISNULL(MarketSegment, '')
                 , ISNULL(ABCLogic, '')
                 , ISNULL(ABCPeriod, 0)
                 , ISNULL(WorkDayPerWeek, 0)
                 , ISNULL(PercentA, 0)
                 , ISNULL(PercentB, 0)
                 , ISNULL(PickFaceMethod, '')
                 , ISNULL(ProductGrouping, '')
                 , ISNULL(PickLocFlag, 'Y')
                 , @c_Username
                 , @c_Username
            FROM dbo.SCE_DL_STORER_STG WITH (NOLOCK)
            WHERE RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;
         END;

         UPDATE dbo.SCE_DL_STORER_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         NEXTITEM:

         FETCH NEXT FROM C_HDR
         INTO @n_RowRefNo
            , @c_Storerkey;
      END;

      CLOSE C_HDR;
      DEALLOCATE C_HDR;

      WHILE @@TRANCOUNT > 0
      COMMIT TRAN;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_STORER_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
   END;

   IF @n_Continue = 1
   BEGIN
      SET @b_Success = 1;
   END;
   ELSE
   BEGIN
      SET @b_Success = 0;
   END;
END;

GO