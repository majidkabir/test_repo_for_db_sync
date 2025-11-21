SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_MBOL_UPDATE_RULES_200001_10     */
/* Creation Date: 21-Feb-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21811 - Data Loader - MBOL Update                       */
/*                                                                      */
/* Usage: MBOLDETUPDATE  @c_InParm1 =  '0' Reject Update                */
/*                       @c_InParm1 =  '1' Allow Update                 */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.2                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 21-Feb-2023  WLChooi   1.0   DevOps Combine Script                   */
/* 01-Jun-2023  WLChooi   1.1   Bug Fix - Initialize value (WL01)       */
/* 14-Jun-2023  WLChooi   1.2   WMS-22828 - Add more columns (WL02)     */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_MBOL_UPDATE_RULES_200001_10] (
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
         , @c_Mbolkey      NVARCHAR(10)  
         , @c_Orderkey     NVARCHAR(10)  
         , @c_PrevMbolkey  NVARCHAR(10) = ''   --WL01

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
   
   DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
        , TRIM(ISNULL(MbolKey,''))
        , TRIM(ISNULL(Orderkey,''))
   FROM dbo.SCE_DL_MBOL_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1'
   
   OPEN C_HDR
   FETCH NEXT FROM C_HDR
   INTO @n_RowRefNo
      , @c_Mbolkey     
      , @c_Orderkey   
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''

      IF @c_PrevMbolkey <> @c_Mbolkey
      BEGIN
         --WL02 S
         UPDATE MBOL
         SET ExternMbolKey    = IIF(ISNULL(STG.ExternMbolKey   ,'') = '', MBOL.ExternMbolKey   , IIF(STG.ExternMbolKey    = '$$','',STG.ExternMbolKey   ))
           , VoyageNumber     = IIF(ISNULL(STG.VoyageNumber    ,'') = '', MBOL.VoyageNumber    , IIF(STG.VoyageNumber     = '$$','',STG.VoyageNumber    ))
           , BookingReference = IIF(ISNULL(STG.BookingReference,'') = '', MBOL.BookingReference, IIF(STG.BookingReference = '$$','',STG.BookingReference))
           , OtherReference   = IIF(ISNULL(STG.OtherReference  ,'') = '', MBOL.OtherReference  , IIF(STG.OtherReference   = '$$','',STG.OtherReference  ))
           , UserDefine01     = IIF(ISNULL(STG.UserDefine01    ,'') = '', MBOL.UserDefine01    , IIF(STG.UserDefine01     = '$$','',STG.UserDefine01    ))
           , UserDefine02     = IIF(ISNULL(STG.UserDefine02    ,'') = '', MBOL.UserDefine02    , IIF(STG.UserDefine02     = '$$','',STG.UserDefine02    ))
           , UserDefine03     = IIF(ISNULL(STG.UserDefine03    ,'') = '', MBOL.UserDefine03    , IIF(STG.UserDefine03     = '$$','',STG.UserDefine03    ))
           , UserDefine04     = IIF(ISNULL(STG.UserDefine04    ,'') = '', MBOL.UserDefine04    , IIF(STG.UserDefine04     = '$$','',STG.UserDefine04    ))
           , UserDefine05     = IIF(ISNULL(STG.UserDefine05    ,'') = '', MBOL.UserDefine05    , IIF(STG.UserDefine05     = '$$','',STG.UserDefine05    ))
           , UserDefine06     = IIF(ISNULL(STG.UserDefine06    ,'') = '', MBOL.UserDefine06    , IIF(STG.UserDefine06     = '$$','',STG.UserDefine06    ))
           , UserDefine07     = IIF(ISNULL(STG.UserDefine07    ,'') = '', MBOL.UserDefine07    , IIF(STG.UserDefine07     = '$$','',STG.UserDefine07    ))
           , UserDefine08     = IIF(ISNULL(STG.UserDefine08    ,'') = '', MBOL.UserDefine08    , IIF(STG.UserDefine08     = '$$','',STG.UserDefine08    ))
           , UserDefine09     = IIF(ISNULL(STG.UserDefine09    ,'') = '', MBOL.UserDefine09    , IIF(STG.UserDefine09     = '$$','',STG.UserDefine09    ))
           , UserDefine10     = IIF(ISNULL(STG.UserDefine10    ,'') = '', MBOL.UserDefine10    , IIF(STG.UserDefine10     = '$$','',STG.UserDefine10    ))
           , DestinationCountry          = IIF(ISNULL(STG.DestinationCountry       ,'') = '', MBOL.DestinationCountry       , IIF(STG.DestinationCountry        = '$$', '', STG.DestinationCountry       ))
           , VesselQualifier             = IIF(ISNULL(STG.VesselQualifier          ,'') = '', MBOL.VesselQualifier          , IIF(STG.VesselQualifier           = '$$', '', STG.VesselQualifier          ))
           , Vessel                      = IIF(ISNULL(STG.Vessel                   ,'') = '', MBOL.Vessel                   , IIF(STG.Vessel                    = '$$', '', STG.Vessel                   ))
           , PlaceOfLoadingQualifier     = IIF(ISNULL(STG.PlaceOfLoadingQualifier  ,'') = '', MBOL.PlaceOfLoadingQualifier  , IIF(STG.PlaceOfLoadingQualifier   = '$$', '', STG.PlaceOfLoadingQualifier  ))
           , PlaceOfLoading              = IIF(ISNULL(STG.PlaceOfLoading           ,'') = '', MBOL.PlaceOfLoading           , IIF(STG.PlaceOfLoading            = '$$', '', STG.PlaceOfLoading           ))
           , PlaceOfdischargeQualifier   = IIF(ISNULL(STG.PlaceOfdischargeQualifier,'') = '', MBOL.PlaceOfdischargeQualifier, IIF(STG.PlaceOfdischargeQualifier = '$$', '', STG.PlaceOfdischargeQualifier))
           , PlaceOfDischarge            = IIF(ISNULL(STG.PlaceOfDischarge         ,'') = '', MBOL.PlaceOfDischarge         , IIF(STG.PlaceOfDischarge          = '$$', '', STG.PlaceOfDischarge         ))
           , PlaceOfdeliveryQualifier    = IIF(ISNULL(STG.PlaceOfdeliveryQualifier ,'') = '', MBOL.PlaceOfdeliveryQualifier , IIF(STG.PlaceOfdeliveryQualifier  = '$$', '', STG.PlaceOfdeliveryQualifier ))
           , PlaceOfdelivery             = IIF(ISNULL(STG.PlaceOfdelivery          ,'') = '', MBOL.PlaceOfdelivery          , IIF(STG.PlaceOfdelivery           = '$$', '', STG.PlaceOfdelivery          ))
           , TransMethod                 = IIF(ISNULL(STG.TransMethod              ,'') = '', MBOL.TransMethod              , IIF(STG.TransMethod               = '$$', '', STG.TransMethod              ))
           , CarrierKey    = IIF(ISNULL(STG.CarrierKey  ,'') = '', MBOL.CarrierKey  , IIF(STG.CarrierKey   = '$$', '', STG.CarrierKey  ))
           , Carrieragent  = IIF(ISNULL(STG.Carrieragent,'') = '', MBOL.Carrieragent, IIF(STG.Carrieragent = '$$', '', STG.Carrieragent))
           , [TimeStamp]   = IIF(ISNULL(STG.[TimeStamp] ,'') = '', MBOL.[TimeStamp] , IIF(STG.[TimeStamp]  = '$$', '', STG.[TimeStamp] ))
           , DRIVERName    = IIF(ISNULL(STG.DRIVERName  ,'') = '', MBOL.DRIVERName  , IIF(STG.DRIVERName   = '$$', '', STG.DRIVERName  ))
           , Remarks       = IIF(ISNULL(STG.Remarks     ,'') = '', MBOL.Remarks     , IIF(STG.Remarks      = '$$', '', STG.Remarks     ))
           , Facility      = IIF(ISNULL(STG.Facility    ,'') = '', MBOL.Facility    , IIF(STG.Facility     = '$$', '', STG.Facility    ))
           , COD_Status    = IIF(ISNULL(STG.COD_Status  ,'') = '', MBOL.COD_Status  , IIF(STG.COD_Status   = '$$', '', STG.COD_Status  ))
           , DepotStatus   = IIF(ISNULL(STG.DepotStatus ,'') = '', MBOL.DepotStatus , IIF(STG.DepotStatus  = '$$', '', STG.DepotStatus ))
           , DepartureDate                = IIF(ISNULL(STG.DepartureDate                , '1900-01-01') = '1900-01-01', MBOL.DepartureDate               , STG.DepartureDate                 )
           , ArrivalDate                  = IIF(ISNULL(STG.ArrivalDate                  , '1900-01-01') = '1900-01-01', MBOL.ArrivalDate                  , STG.ArrivalDate                  )
           , ArrivalDateFinalDestination  = IIF(ISNULL(STG.ArrivalDateFinalDestination  , '1900-01-01') = '1900-01-01', MBOL.ArrivalDateFinalDestination  , STG.ArrivalDateFinalDestination  )
           , EffectiveDate                = IIF(ISNULL(STG.EffectiveDate                , '1900-01-01') = '1900-01-01', MBOL.EffectiveDate                , STG.EffectiveDate                )
           , LoadingDate                  = IIF(ISNULL(STG.LoadingDate                  , '1900-01-01') = '1900-01-01', MBOL.LoadingDate                  , STG.LoadingDate                  )
           , CustomerReceivedDate         = IIF(ISNULL(STG.CustomerReceivedDate         , '1900-01-01') = '1900-01-01', MBOL.CustomerReceivedDate         , STG.CustomerReceivedDate         )
           , GIS_ProcessTime              = IIF(ISNULL(STG.GIS_ProcessTime              , '1900-01-01') = '1900-01-01', MBOL.GIS_ProcessTime              , STG.GIS_ProcessTime              )
           , Cust_EDIAckTime              = IIF(ISNULL(STG.Cust_EDIAckTime              , '1900-01-01') = '1900-01-01', MBOL.Cust_EDIAckTime              , STG.Cust_EDIAckTime              )
           , ShipDate                     = IIF(ISNULL(STG.ShipDate                     , '1900-01-01') = '1900-01-01', MBOL.ShipDate                     , STG.ShipDate                     )
           , TotalInvoiceValue = IIF(ISNULL(STG.TotalInvoiceValue, 0) = 0, MBOL.TotalInvoiceValue, STG.TotalInvoiceValue)
           , GrossWeight       = IIF(ISNULL(STG.GrossWeight  , 0) = 0, MBOL.GrossWeight  , STG.GrossWeight  )
           , Capacity          = IIF(ISNULL(STG.Capacity     , 0) = 0, MBOL.Capacity     , STG.Capacity     )
           , InvoiceAmount     = IIF(ISNULL(STG.InvoiceAmount, 0) = 0, MBOL.InvoiceAmount, STG.InvoiceAmount)
           , [Weight]          = IIF(ISNULL(STG.[Weight]     , 0) = 0, MBOL.[Weight]     , STG.[Weight]     )
           , [Cube]            = IIF(ISNULL(STG.[Cube]       , 0) = 0, MBOL.[Cube]       , STG.[Cube]       )
           , CustCnt           = IIF(ISNULL(STG.CustCnt      , 0) = 0, MBOL.CustCnt      , STG.CustCnt      )
           , PalletCnt         = IIF(ISNULL(STG.PalletCnt    , 0) = 0, MBOL.PalletCnt    , STG.PalletCnt    )
           , CaseCnt           = IIF(ISNULL(STG.CaseCnt      , 0) = 0, MBOL.CaseCnt      , STG.CaseCnt      )
           , ShipCounter       = IIF(ISNULL(STG.ShipCounter  , 0) = 0, MBOL.ShipCounter  , STG.ShipCounter  )
           , NoofContainer     = IIF(ISNULL(STG.NoofContainer, 0) = 0, MBOL.NoofContainer, STG.NoofContainer)
           , CTNTYPE1   = IIF(ISNULL(STG.CTNTYPE1  ,'') = '', MBOL.CTNTYPE1  , IIF(STG.CTNTYPE1   = '$$', '', STG.CTNTYPE1  ))
           , CTNTYPE2   = IIF(ISNULL(STG.CTNTYPE2  ,'') = '', MBOL.CTNTYPE2  , IIF(STG.CTNTYPE2   = '$$', '', STG.CTNTYPE2  ))
           , CTNTYPE3   = IIF(ISNULL(STG.CTNTYPE3  ,'') = '', MBOL.CTNTYPE3  , IIF(STG.CTNTYPE3   = '$$', '', STG.CTNTYPE3  ))
           , CTNTYPE4   = IIF(ISNULL(STG.CTNTYPE4  ,'') = '', MBOL.CTNTYPE4  , IIF(STG.CTNTYPE4   = '$$', '', STG.CTNTYPE4  ))
           , CTNTYPE5   = IIF(ISNULL(STG.CTNTYPE5  ,'') = '', MBOL.CTNTYPE5  , IIF(STG.CTNTYPE5   = '$$', '', STG.CTNTYPE5  ))
           , CTNTYPE6   = IIF(ISNULL(STG.CTNTYPE6  ,'') = '', MBOL.CTNTYPE6  , IIF(STG.CTNTYPE6   = '$$', '', STG.CTNTYPE6  ))
           , CTNTYPE7   = IIF(ISNULL(STG.CTNTYPE7  ,'') = '', MBOL.CTNTYPE7  , IIF(STG.CTNTYPE7   = '$$', '', STG.CTNTYPE7  ))
           , CTNTYPE8   = IIF(ISNULL(STG.CTNTYPE8  ,'') = '', MBOL.CTNTYPE8  , IIF(STG.CTNTYPE8   = '$$', '', STG.CTNTYPE8  ))
           , CTNTYPE9   = IIF(ISNULL(STG.CTNTYPE9  ,'') = '', MBOL.CTNTYPE9  , IIF(STG.CTNTYPE9   = '$$', '', STG.CTNTYPE9  ))
           , CTNTYPE10  = IIF(ISNULL(STG.CTNTYPE10 ,'') = '', MBOL.CTNTYPE10 , IIF(STG.CTNTYPE10  = '$$', '', STG.CTNTYPE10 ))
           , PACKTYPE1  = IIF(ISNULL(STG.PACKTYPE1 ,'') = '', MBOL.PACKTYPE1 , IIF(STG.PACKTYPE1  = '$$', '', STG.PACKTYPE1 ))
           , PACKTYPE2  = IIF(ISNULL(STG.PACKTYPE2 ,'') = '', MBOL.PACKTYPE2 , IIF(STG.PACKTYPE2  = '$$', '', STG.PACKTYPE2 ))
           , PACKTYPE3  = IIF(ISNULL(STG.PACKTYPE3 ,'') = '', MBOL.PACKTYPE3 , IIF(STG.PACKTYPE3  = '$$', '', STG.PACKTYPE3 ))
           , PACKTYPE4  = IIF(ISNULL(STG.PACKTYPE4 ,'') = '', MBOL.PACKTYPE4 , IIF(STG.PACKTYPE4  = '$$', '', STG.PACKTYPE4 ))
           , PACKTYPE5  = IIF(ISNULL(STG.PACKTYPE5 ,'') = '', MBOL.PACKTYPE5 , IIF(STG.PACKTYPE5  = '$$', '', STG.PACKTYPE5 ))
           , PACKTYPE6  = IIF(ISNULL(STG.PACKTYPE6 ,'') = '', MBOL.PACKTYPE6 , IIF(STG.PACKTYPE6  = '$$', '', STG.PACKTYPE6 ))
           , PACKTYPE7  = IIF(ISNULL(STG.PACKTYPE7 ,'') = '', MBOL.PACKTYPE7 , IIF(STG.PACKTYPE7  = '$$', '', STG.PACKTYPE7 ))
           , PACKTYPE8  = IIF(ISNULL(STG.PACKTYPE8 ,'') = '', MBOL.PACKTYPE8 , IIF(STG.PACKTYPE8  = '$$', '', STG.PACKTYPE8 ))
           , PACKTYPE9  = IIF(ISNULL(STG.PACKTYPE9 ,'') = '', MBOL.PACKTYPE9 , IIF(STG.PACKTYPE9  = '$$', '', STG.PACKTYPE9 ))
           , PACKTYPE10 = IIF(ISNULL(STG.PACKTYPE10,'') = '', MBOL.PACKTYPE10, IIF(STG.PACKTYPE10 = '$$', '', STG.PACKTYPE10))
           , CTNCNT1  = IIF(ISNULL(STG.CTNCNT1 , 0) = 0, MBOL.CTNCNT1 , STG.CTNCNT1 )
           , CTNCNT2  = IIF(ISNULL(STG.CTNCNT2 , 0) = 0, MBOL.CTNCNT2 , STG.CTNCNT2 )
           , CTNCNT3  = IIF(ISNULL(STG.CTNCNT3 , 0) = 0, MBOL.CTNCNT3 , STG.CTNCNT3 )
           , CTNCNT4  = IIF(ISNULL(STG.CTNCNT4 , 0) = 0, MBOL.CTNCNT4 , STG.CTNCNT4 )
           , CTNCNT5  = IIF(ISNULL(STG.CTNCNT5 , 0) = 0, MBOL.CTNCNT5 , STG.CTNCNT5 )
           , CTNCNT6  = IIF(ISNULL(STG.CTNCNT6 , 0) = 0, MBOL.CTNCNT6 , STG.CTNCNT6 )
           , CTNCNT7  = IIF(ISNULL(STG.CTNCNT7 , 0) = 0, MBOL.CTNCNT7 , STG.CTNCNT7 )
           , CTNCNT8  = IIF(ISNULL(STG.CTNCNT8 , 0) = 0, MBOL.CTNCNT8 , STG.CTNCNT8 )
           , CTNCNT9  = IIF(ISNULL(STG.CTNCNT9 , 0) = 0, MBOL.CTNCNT9 , STG.CTNCNT9 )
           , CTNCNT10 = IIF(ISNULL(STG.CTNCNT10, 0) = 0, MBOL.CTNCNT10, STG.CTNCNT10)
           , CTNQTY1  = IIF(ISNULL(STG.CTNQTY1 , 0) = 0, MBOL.CTNQTY1 , STG.CTNQTY1 )
           , CTNQTY2  = IIF(ISNULL(STG.CTNQTY2 , 0) = 0, MBOL.CTNQTY2 , STG.CTNQTY2 )
           , CTNQTY3  = IIF(ISNULL(STG.CTNQTY3 , 0) = 0, MBOL.CTNQTY3 , STG.CTNQTY3 )
           , CTNQTY4  = IIF(ISNULL(STG.CTNQTY4 , 0) = 0, MBOL.CTNQTY4 , STG.CTNQTY4 )
           , CTNQTY5  = IIF(ISNULL(STG.CTNQTY5 , 0) = 0, MBOL.CTNQTY5 , STG.CTNQTY5 )
           , CTNQTY6  = IIF(ISNULL(STG.CTNQTY6 , 0) = 0, MBOL.CTNQTY6 , STG.CTNQTY6 )
           , CTNQTY7  = IIF(ISNULL(STG.CTNQTY7 , 0) = 0, MBOL.CTNQTY7 , STG.CTNQTY7 )
           , CTNQTY8  = IIF(ISNULL(STG.CTNQTY8 , 0) = 0, MBOL.CTNQTY8 , STG.CTNQTY8 )
           , CTNQTY9  = IIF(ISNULL(STG.CTNQTY9 , 0) = 0, MBOL.CTNQTY9 , STG.CTNQTY9 )
           , CTNQTY10 = IIF(ISNULL(STG.CTNQTY10, 0) = 0, MBOL.CTNQTY10, STG.CTNQTY10)
           , NoOfMasterCtn          = IIF(ISNULL(STG.NoOfMasterCtn        , 0) = 0, MBOL.NoOfMasterCtn        , STG.NoOfMasterCtn        )
           , NoOfPrepacks           = IIF(ISNULL(STG.NoOfPrepacks         , 0) = 0, MBOL.NoOfPrepacks         , STG.NoOfPrepacks         )
           , NoofReshippableCarton  = IIF(ISNULL(STG.NoofReshippableCarton, 0) = 0, MBOL.NoofReshippableCarton, STG.NoofReshippableCarton)
           , NoofCartonPacked       = IIF(ISNULL(STG.NoofCartonPacked     , 0) = 0, MBOL.NoofCartonPacked     , STG.NoofCartonPacked     )
           , NoofIDSCarton          = IIF(ISNULL(STG.NoofIDSCarton        , 0) = 0, MBOL.NoofIDSCarton        , STG.NoofIDSCarton        )
           , NoofCustomerCarton     = IIF(ISNULL(STG.NoofCustomerCarton   , 0) = 0, MBOL.NoofCustomerCarton   , STG.NoofCustomerCarton   )      
           , NoofPallets            = IIF(ISNULL(STG.NoofPallets          , 0) = 0, MBOL.NoofPallets          , STG.NoofPallets          )
           , CartonWeight           = IIF(ISNULL(STG.CartonWeight         , 0) = 0, MBOL.CartonWeight         , STG.CartonWeight         )
           , CartonCube             = IIF(ISNULL(STG.CartonCube           , 0) = 0, MBOL.CartonCube           , STG.CartonCube           )
           , CBOLKey                = IIF(ISNULL(STG.CBOLKey              , 0) = 0, MBOL.CBOLKey              , STG.CBOLKey              )
           , CTNTYPE                = IIF(ISNULL(STG.CTNTYPE             ,'') = '', MBOL.CTNTYPE             , IIF(STG.CTNTYPE              = '$$', '', STG.CTNTYPE             ))  
           , WeightUnit             = IIF(ISNULL(STG.WeightUnit          ,'') = '', MBOL.WeightUnit          , IIF(STG.WeightUnit           = '$$', '', STG.WeightUnit          ))
           , CubeUnit               = IIF(ISNULL(STG.CubeUnit            ,'') = '', MBOL.CubeUnit            , IIF(STG.CubeUnit             = '$$', '', STG.CubeUnit            ))
           , ShipperAccountCode     = IIF(ISNULL(STG.ShipperAccountCode  ,'') = '', MBOL.ShipperAccountCode  , IIF(STG.ShipperAccountCode   = '$$', '', STG.ShipperAccountCode  ))
           , ConsigneeAccountCode   = IIF(ISNULL(STG.ConsigneeAccountCode,'') = '', MBOL.ConsigneeAccountCode, IIF(STG.ConsigneeAccountCode = '$$', '', STG.ConsigneeAccountCode))
           , NotifyAccountCode      = IIF(ISNULL(STG.NotifyAccountCode   ,'') = '', MBOL.NotifyAccountCode   , IIF(STG.NotifyAccountCode    = '$$', '', STG.NotifyAccountCode   ))
           , ContainerNo            = IIF(ISNULL(STG.ContainerNo         ,'') = '', MBOL.ContainerNo         , IIF(STG.ContainerNo          = '$$', '', STG.ContainerNo         ))
           , Equipment              = IIF(ISNULL(STG.Equipment           ,'') = '', MBOL.Equipment           , IIF(STG.Equipment            = '$$', '', STG.Equipment           ))
           , SealNo                 = IIF(ISNULL(STG.SealNo              ,'') = '', MBOL.SealNo              , IIF(STG.SealNo               = '$$', '', STG.SealNo              ))
           , GIS_ControlNo          = IIF(ISNULL(STG.GIS_ControlNo       ,'') = '', MBOL.GIS_ControlNo       , IIF(STG.GIS_ControlNo        = '$$', '', STG.GIS_ControlNo       ))
           , Cust_ISA_ControlNo     = IIF(ISNULL(STG.Cust_ISA_ControlNo  ,'') = '', MBOL.Cust_ISA_ControlNo  , IIF(STG.Cust_ISA_ControlNo   = '$$', '', STG.Cust_ISA_ControlNo  ))
           , Cust_GIS_ControlNo     = IIF(ISNULL(STG.Cust_GIS_ControlNo  ,'') = '', MBOL.Cust_GIS_ControlNo  , IIF(STG.Cust_GIS_ControlNo   = '$$', '', STG.Cust_GIS_ControlNo  ))
           , CBOLLineNumber         = IIF(ISNULL(STG.CBOLLineNumber      ,'') = '', MBOL.CBOLLineNumber      , IIF(STG.CBOLLineNumber       = '$$', '', STG.CBOLLineNumber      ))
           , [Route]                = IIF(ISNULL(STG.[Route]             ,'') = '', MBOL.[Route]             , IIF(STG.[Route]              = '$$', '', STG.[Route]             ))
           , Vehicle_Type           = IIF(ISNULL(STG.Vehicle_Type        ,'') = '', MBOL.Vehicle_Type        , IIF(STG.Vehicle_Type         = '$$', '', STG.Vehicle_Type        ))
           , Delivery_Zone          = IIF(ISNULL(STG.Delivery_Zone       ,'') = '', MBOL.Delivery_Zone       , IIF(STG.Delivery_Zone        = '$$', '', STG.Delivery_Zone       ))
           , OTMShipmentID          = IIF(ISNULL(STG.OTMShipmentID       ,'') = '', MBOL.OTMShipmentID       , IIF(STG.OTMShipmentID        = '$$', '', STG.OTMShipmentID       ))
           --WL02 E
           , EditDate = GETDATE()
           , EditWho = SUSER_SNAME()
         FROM SCE_DL_MBOL_STG STG WITH (NOLOCK)
         JOIN MBOL WITH (NOLOCK) ON (STG.MbolKey = MBOL.MbolKey)
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND MBOL.MbolKey = @c_Mbolkey

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      
         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END
      
      IF @c_InParm1 = '1'
      BEGIN
         --WL02 S
         UPDATE MBOLDETAIL
         SET [Weight] = CASE WHEN ISNULL(STG.DWeight, 0) = 0 THEN MBOLDETAIL.[Weight]
                             ELSE STG.DWeight END
           , [Cube] = CASE WHEN ISNULL(STG.DCube, 0) = 0 THEN MBOLDETAIL.[Cube]
                           ELSE STG.DCube END
           , CtnCnt1 = CASE WHEN ISNULL(STG.DCtnCnt1, 0) = 0 THEN MBOLDETAIL.CtnCnt1
                            ELSE STG.DCtnCnt1 END
           , CtnCnt2 = CASE WHEN ISNULL(STG.DCtnCnt2, 0) = 0 THEN MBOLDETAIL.CtnCnt2
                            ELSE STG.DCtnCnt2 END
           , CtnCnt3 = CASE WHEN ISNULL(STG.DCtnCnt3, 0) = 0 THEN MBOLDETAIL.CtnCnt3
                            ELSE STG.DCtnCnt3 END
           , CtnCnt4 = CASE WHEN ISNULL(STG.DCtnCnt4, 0) = 0 THEN MBOLDETAIL.CtnCnt4
                            ELSE STG.DCtnCnt4 END
           , CtnCnt5 = CASE WHEN ISNULL(STG.DCtnCnt5, 0) = 0 THEN MBOLDETAIL.CtnCnt5
                            ELSE STG.DCtnCnt5 END
           , UserDefine01 = IIF(ISNULL(STG.DUdef01,'') = '', MBOLDETAIL.UserDefine01, IIF(STG.DUdef01 = '$$', '', STG.DUdef01))
           , UserDefine02 = IIF(ISNULL(STG.DUdef02,'') = '', MBOLDETAIL.UserDefine02, IIF(STG.DUdef02 = '$$', '', STG.DUdef02))
           , UserDefine03 = IIF(ISNULL(STG.DUdef03,'') = '', MBOLDETAIL.UserDefine03, IIF(STG.DUdef03 = '$$', '', STG.DUdef03))
           , UserDefine04 = IIF(ISNULL(STG.DUdef04,'') = '', MBOLDETAIL.UserDefine04, IIF(STG.DUdef04 = '$$', '', STG.DUdef04))
           , UserDefine05 = IIF(ISNULL(STG.DUdef05,'') = '', MBOLDETAIL.UserDefine05, IIF(STG.DUdef05 = '$$', '', STG.DUdef05))
           , UserDefine06 = IIF(ISNULL(STG.DUdef06,'') = '', MBOLDETAIL.UserDefine06, IIF(STG.DUdef06 = '$$', '', STG.DUdef06))
           , UserDefine07 = IIF(ISNULL(STG.DUdef07,'') = '', MBOLDETAIL.UserDefine07, IIF(STG.DUdef07 = '$$', '', STG.DUdef07))
           , UserDefine08 = IIF(ISNULL(STG.DUdef08,'') = '', MBOLDETAIL.UserDefine08, IIF(STG.DUdef08 = '$$', '', STG.DUdef08))
           , UserDefine09 = IIF(ISNULL(STG.DUdef09,'') = '', MBOLDETAIL.UserDefine09, IIF(STG.DUdef09 = '$$', '', STG.DUdef09))
           , UserDefine10 = IIF(ISNULL(STG.DUdef10,'') = '', MBOLDETAIL.UserDefine10, IIF(STG.DUdef10 = '$$', '', STG.DUdef10))
           , TotalCartons = CASE WHEN ISNULL(STG.TotalCartons, 0) = 0 THEN MBOLDETAIL.TotalCartons
                                 ELSE STG.TotalCartons END
           , TotCtnCube = CASE WHEN ISNULL(STG.TotCtnCube, 0) = 0 THEN MBOLDETAIL.TotCtnCube
                               ELSE STG.TotCtnCube END
           , TotCtnWeight = CASE WHEN ISNULL(STG.TotCtnWeight, 0) = 0 THEN MBOLDETAIL.TotCtnWeight
                                 ELSE STG.TotCtnWeight END
           , ContainerKey     = IIF(ISNULL(STG.ContainerKey   ,'') = '', MBOLDETAIL.ContainerKey   , IIF(STG.ContainerKey    = '$$', '', STG.ContainerKey   ))
           , PalletKey        = IIF(ISNULL(STG.PalletKey      ,'') = '', MBOLDETAIL.PalletKey      , IIF(STG.PalletKey       = '$$', '', STG.PalletKey      ))
           , [Description]    = IIF(ISNULL(STG.[Description]  ,'') = '', MBOLDETAIL.[Description]  , IIF(STG.[Description]   = '$$', '', STG.[Description]  ))
           , InvoiceNo        = IIF(ISNULL(STG.DInvoiceNo     ,'') = '', MBOLDETAIL.InvoiceNo      , IIF(STG.DInvoiceNo      = '$$', '', STG.DInvoiceNo     ))
           , UPSINum          = IIF(ISNULL(STG.UPSINum        ,'') = '', MBOLDETAIL.UPSINum        , IIF(STG.UPSINum         = '$$', '', STG.UPSINum        ))
           , PCMNum           = IIF(ISNULL(STG.PCMNum         ,'') = '', MBOLDETAIL.PCMNum         , IIF(STG.PCMNum          = '$$', '', STG.PCMNum         ))
           , ExternReason     = IIF(ISNULL(STG.ExternReason   ,'') = '', MBOLDETAIL.ExternReason   , IIF(STG.ExternReason    = '$$', '', STG.ExternReason   ))
           , InvoiceStatus    = IIF(ISNULL(STG.InvoiceStatus  ,'') = '', MBOLDETAIL.InvoiceStatus  , IIF(STG.InvoiceStatus   = '$$', '', STG.InvoiceStatus  ))
           , OfficialReceipt  = IIF(ISNULL(STG.OfficialReceipt,'') = '', MBOLDETAIL.OfficialReceipt, IIF(STG.OfficialReceipt = '$$', '', STG.OfficialReceipt))
           , ITS              = IIF(ISNULL(STG.ITS            ,'') = '', MBOLDETAIL.ITS            , IIF(STG.ITS             = '$$', '', STG.ITS            ))
           , LoadKey          = IIF(ISNULL(STG.LoadKey        ,'') = '', MBOLDETAIL.LoadKey        , IIF(STG.LoadKey         = '$$', '', STG.LoadKey        ))
           , DeliveryStatus   = IIF(ISNULL(STG.DeliveryStatus ,'') = '', MBOLDETAIL.DeliveryStatus , IIF(STG.DeliveryStatus  = '$$', '', STG.DeliveryStatus ))
           , ExternOrderKey   = IIF(ISNULL(STG.ExternOrderKey ,'') = '', MBOLDETAIL.ExternOrderKey , IIF(STG.ExternOrderKey  = '$$', '', STG.ExternOrderKey ))
           , DriverName       = IIF(ISNULL(STG.DriverName     ,'') = '', MBOLDETAIL.DriverName     , IIF(STG.DriverName      = '$$', '', STG.DriverName     ))
           , VehicleNo        = IIF(ISNULL(STG.VehicleNo      ,'') = '', MBOLDETAIL.VehicleNo      , IIF(STG.VehicleNo       = '$$', '', STG.VehicleNo      ))
           , TruckType        = IIF(ISNULL(STG.TruckType      ,'') = '', MBOLDETAIL.TruckType      , IIF(STG.TruckType       = '$$', '', STG.TruckType      ))
           , ServiceProvider  = IIF(ISNULL(STG.ServiceProvider,'') = '', MBOLDETAIL.ServiceProvider, IIF(STG.ServiceProvider = '$$', '', STG.ServiceProvider))
           , InvoiceAmount = IIF(ISNULL(STG.DInvoiceAmount, 0) = 0, MBOLDETAIL.InvoiceAmount, STG.DInvoiceAmount)
           , GrossWeight   = IIF(ISNULL(STG.DGrossWeight  , 0) = 0, MBOLDETAIL.GrossWeight  , STG.DGrossWeight  )
           , Capacity      = IIF(ISNULL(STG.DCapacity     , 0) = 0, MBOLDETAIL.Capacity     , STG.DCapacity     )
           , OrderDate    = IIF(ISNULL(STG.OrderDate   , '1900-01-01') = '1900-01-01', MBOLDETAIL.OrderDate   , STG.OrderDate   )
           , DeliveryTime = IIF(ISNULL(STG.DeliveryTime, '1900-01-01') = '1900-01-01', MBOLDETAIL.DeliveryTime, STG.DeliveryTime)
           , DeliveryDate = IIF(ISNULL(STG.DeliveryDate, '1900-01-01') = '1900-01-01', MBOLDETAIL.DeliveryDate, STG.DeliveryDate)
           --WL02 E
           , EditDate = GETDATE()
           , EditWho = SUSER_SNAME()
         FROM SCE_DL_MBOL_STG STG WITH (NOLOCK)
         JOIN MBOLDETAIL WITH (NOLOCK) ON (STG.MbolKey = MBOLDETAIL.MbolKey AND STG.OrderKey = MBOLDETAIL.OrderKey)
         WHERE STG.STG_BatchNo = @n_BatchNo 
         AND MBOLDETAIL.MbolKey = @c_Mbolkey 
         AND MBOLDETAIL.OrderKey = @c_Orderkey

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
         
         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END

      IF @c_ttlMsg = ''
      BEGIN
         UPDATE dbo.SCE_DL_MBOL_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE STG_BatchNo = @n_BatchNo
         AND MBOLKey = @c_Mbolkey
         AND OrderKey = @c_Orderkey

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68001
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_MBOL_UPDATE_RULES_200001_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END
      END
      ELSE
      BEGIN
         BEGIN TRANSACTION
   
         UPDATE dbo.SCE_DL_MBOL_STG WITH (ROWLOCK)
         SET STG_Status = '5'
         WHERE STG_BatchNo = @n_BatchNo
         AND MBOLKey = @c_Mbolkey
         AND OrderKey = @c_Orderkey
   
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68002
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_MBOL_UPDATE_RULES_200001_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END
   
         COMMIT TRANSACTION
      END
      
      SET @c_PrevMbolkey = @c_Mbolkey

      FETCH NEXT FROM C_HDR
      INTO @n_RowRefNo
         , @c_Mbolkey     
         , @c_Orderkey 
   END
   
   CLOSE C_HDR
   DEALLOCATE C_HDR
   
   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_MBOL_UPDATE_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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