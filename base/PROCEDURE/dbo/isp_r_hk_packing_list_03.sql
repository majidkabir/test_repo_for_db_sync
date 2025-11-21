SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_packing_list_03                            */
/* Creation Date: 28-Sep-2017                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: UA Packing List                                              */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_packing_list_03             */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2017-10-01   ML       1.1  Add Parameter @as_mode                     */
/* 2017-12-19   ML       1.2  Increase Carton CBM/Weight to 5 decimals   */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_packing_list_03] (
       @as_storerkey       NVARCHAR(15)
     , @as_loadkey         NVARCHAR(10)
     , @as_packcfmdatefrom NVARCHAR(30)
     , @as_packcfmdateto   NVARCHAR(30)
     , @as_mode            NVARCHAR(10) = '1'
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @as_packcfmdateto = IIF(CONVERT(VARCHAR(12),CAST(@as_packcfmdateto AS DATETIME),114)='00:00:00:000', CONVERT(VARCHAR(10),DATEADD(d,1,@as_packcfmdateto),120), @as_packcfmdateto)

   IF OBJECT_ID('tempdb.dbo.#TEMP_PAKDTL_LABELNO') IS NOT NULL
      DROP TABLE #TEMP_PAKDTL_LABELNO
   IF OBJECT_ID('tempdb.dbo.#TEMP_PAKDTL_DROPID') IS NOT NULL
      DROP TABLE #TEMP_PAKDTL_DROPID


   SELECT PickSlipNo = RTRIM ( PH.PickSlipNo )
        , LabelNo    = RTRIM ( PD.LabelNo )
        , CartonNo   = ROW_NUMBER() OVER ( PARTITION BY PH.PickSlipNo ORDER BY PD.LabelNo )
        , Length     = MAX ( ISNULL( CASE WHEN ISNULL(CZ.CartonLength,0)=0 THEN IIF(ISNUMERIC(UCC.Userdefined05)=1,CONVERT(FLOAT,UCC.Userdefined05),0) ELSE CZ.CartonLength END, 0) )
        , Width      = MAX ( ISNULL( CASE WHEN ISNULL(CZ.CartonWidth ,0)=0 THEN IIF(ISNUMERIC(UCC.Userdefined06)=1,CONVERT(FLOAT,UCC.Userdefined06),0) ELSE CZ.CartonWidth  END, 0) )
        , Height     = MAX ( ISNULL( CASE WHEN ISNULL(CZ.CartonHeight,0)=0 THEN IIF(ISNUMERIC(UCC.Userdefined07)=1,CONVERT(FLOAT,UCC.Userdefined07),0) ELSE CZ.CartonHeight END, 0) )
        , CBM        = MAX ( ISNULL( CASE WHEN ISNULL(PI.Cube        ,0)=0 THEN IIF(ISNUMERIC(UCC.Userdefined08)=1,CONVERT(FLOAT,UCC.Userdefined08),0) ELSE PI.Cube   END, 0) )
        , Weight     = MAX ( ISNULL( CASE WHEN ISNULL(PI.Weight      ,0)=0 THEN IIF(ISNUMERIC(UCC.Userdefined04)=1,CONVERT(FLOAT,UCC.Userdefined04),0) ELSE PI.Weight END, 0) )
   INTO #TEMP_PAKDTL_LABELNO
   FROM dbo.ORDERS     OH (NOLOCK)
   JOIN dbo.PACKHEADER PH (NOLOCK) ON (OH.OrderKey=PH.OrderKey)
   JOIN dbo.PACKDETAIL PD (NOLOCK) ON (PH.PickSlipNo=PD.PickSlipNo)
   LEFT OUTER JOIN dbo.UCC          UCC (NOLOCK) ON (PD.DropID=UCC.UCCNo)
   LEFT OUTER JOIN dbo.PACKINFO      PI (NOLOCK) ON (PD.PickSlipNo=PI.PickSlipNo AND PD.CartonNo=PI.CartonNo)
   LEFT OUTER JOIN dbo.CARTONIZATION CZ (NOLOCK) ON (PI.CartonType=CZ.CartonType)
   WHERE PH.Status = '9'
     AND PD.LabelNo <> ''
     AND PD.Qty > 0
     AND OH.StorerKey = @as_storerkey
     AND OH.Loadkey   = @as_loadkey
     AND PH.EditDate >= @as_packcfmdatefrom
     AND PH.EditDate <  @as_packcfmdateto
   GROUP BY PH.PickSlipNo
          , PD.LabelNo


   SELECT PickSlipNo = RTRIM( PH.PickSlipNo )
        , LabelNo    = MAX ( RTRIM( PD.LabelNo ) )
        , DropID     = RTRIM( PD.DropID )
        , CartonNo   = ROW_NUMBER() OVER ( PARTITION BY PH.PickSlipNo ORDER BY PD.DropID )
        , Length     = MAX ( ISNULL( CASE WHEN ISNULL(CZ.CartonLength,0)=0 THEN IIF(ISNUMERIC(UCC.Userdefined05)=1,CONVERT(FLOAT,UCC.Userdefined05),0) ELSE CZ.CartonLength END, 0) )
        , Width      = MAX ( ISNULL( CASE WHEN ISNULL(CZ.CartonWidth ,0)=0 THEN IIF(ISNUMERIC(UCC.Userdefined06)=1,CONVERT(FLOAT,UCC.Userdefined06),0) ELSE CZ.CartonWidth  END, 0) )
        , Height     = MAX ( ISNULL( CASE WHEN ISNULL(CZ.CartonHeight,0)=0 THEN IIF(ISNUMERIC(UCC.Userdefined07)=1,CONVERT(FLOAT,UCC.Userdefined07),0) ELSE CZ.CartonHeight END, 0) )
        , CBM        = MAX ( ISNULL( CASE WHEN ISNULL(PI.Cube        ,0)=0 THEN IIF(ISNUMERIC(UCC.Userdefined08)=1,CONVERT(FLOAT,UCC.Userdefined08),0) ELSE PI.Cube   END, 0) )
        , Weight     = MAX ( ISNULL( CASE WHEN ISNULL(PI.Weight      ,0)=0 THEN IIF(ISNUMERIC(UCC.Userdefined04)=1,CONVERT(FLOAT,UCC.Userdefined04),0) ELSE PI.Weight END, 0) )
   INTO #TEMP_PAKDTL_DROPID
   FROM dbo.ORDERS     OH (NOLOCK)
   JOIN dbo.PACKHEADER PH (NOLOCK) ON (OH.Orderkey=PH.Orderkey)
   JOIN dbo.PACKDETAIL PD (NOLOCK) ON (PH.PickSlipNo=PD.PickSlipNo)
   LEFT OUTER JOIN dbo.UCC          UCC (NOLOCK) ON (PD.DropID=UCC.UCCNo)
   LEFT OUTER JOIN dbo.PACKINFO      PI (NOLOCK) ON (PD.PickSlipNo=PI.PickSlipNo AND PD.CartonNo=PI.CartonNo)
   LEFT OUTER JOIN dbo.CARTONIZATION CZ (NOLOCK) ON (PI.CartonType=CZ.CartonType)
   WHERE PH.Status = '9'
     AND PD.DropID <> ''
     AND PD.Qty > 0
     AND OH.StorerKey = @as_storerkey
     AND OH.Loadkey   = @as_loadkey
     AND PH.EditDate >= @as_packcfmdatefrom
     AND PH.EditDate <  @as_packcfmdateto
   GROUP BY PH.PickSlipNo
          , PD.DropID


   SELECT [StorerKey]              = X.StorerKey
        , [OrderKey]               = X.OrderKey
        , [ConsigneeKey]           = X.ConsigneeKey
        , [C_Company]              = X.C_Company
        , [C_Address]              = X.C_Address
        , [Ship To Country]        = X.C_Country
        , [LoadKey]                = X.LoadKey
        , [UA Order Reference]     = X.OH_UserDefine02
        , [UA OBD]                 = X.ExternOrderKey
        , [LPN]                    = X.LabelNo
        , [CartonNo]               = X.CartonNo
        , [Carton CBM]             = ROUND ( X.CTN_CBM    * X.Qty / SUM( X.Qty ) OVER(PARTITION BY X.LabelNo), 5 )
        , [Carton Dimension (cm)]  = CONVERT(NVARCHAR(20),X.Carton_Length) + ' x ' + CONVERT(NVARCHAR(20),X.Carton_Width) + ' x ' + CONVERT(NVARCHAR(20),X.Carton_Height)
        , [Carton Weight]          = ROUND ( X.CTN_Weight * X.Qty / SUM( X.Qty ) OVER(PARTITION BY X.LabelNo), 5 )
        , [SKU]                    = X.SKU
        , [SKU Description]        = X.SKUDescr
        , [UPC]                    = X.ALTSKU
        , [Style]                  = X.Style
        , [Color]                  = X.Color
        , [Size]                   = X.Size
        , [Packed Qty (Pc)]        = X.Qty
        , [Country of Origin]      = X.COO
        , [Order Status]           = X.OH_Status
        , [Wave Description]       = X.Wave_Descr
        , [Pack Confirm DateTime]  = X.PH_EditDate
        , [LoadPlan Delivery Date] = X.LpUserdefDate01
        , [OrderGroup]             = X.OrderGroup
        , [Wavekey]                = X.Wavekey
        , [PO Number]              = X.PO_Number

   FROM (
      SELECT StorerKey       = RTRIM ( MAX ( OH.StorerKey ) )
           , OrderKey        = OH.Orderkey
           , ConsigneeKey    = RTRIM ( MAX ( OH.ConsigneeKey ) )
           , C_Company       = RTRIM ( MAX ( OH.C_Company ) )
           , C_Address       = MAX ( RTRIM(OH.C_Address1) + ', ' + RTRIM(OH.C_Address2) + ', ' + RTRIM(OH.C_Address3) + ', ' + RTRIM(OH.C_Address4) )
           , C_Country       = RTRIM ( MAX ( OH.C_Country ) )
           , LoadKey         = RTRIM ( MAX ( OH.LoadKey ) )
           , OH_UserDefine02 = RTRIM ( MAX ( OH.UserDefine02 ) )
           , ExternOrderKey  = RTRIM ( MAX ( OH.ExternOrderKey ) )
           , LabelNo         = ISNULL ( PAKDTL_DI.LabelNo , PAKDTL_LN.LabelNo  )
           , CartonNo        = ISNULL ( PAKDTL_DI.CartonNo, PAKDTL_LN.CartonNo )
           , SKU             = RTRIM ( PD.Sku )
           , SKUDescr        = RTRIM ( MAX ( SKU.DESCR ) )
           , ALTSKU          = RTRIM ( MAX ( SKU.ALTSKU ) )
           , Style           = RTRIM ( MAX ( SKU.Style ) )
           , Color           = RTRIM ( MAX ( SKU.Color ) )
           , Size            = RTRIM ( MAX ( SKU.Size ) )
           , Qty             = SUM ( PD.Qty )
           , COO             = RTRIM ( LA.Lottable08 )
           , OH_Status       = RTRIM ( MAX ( OH.Status ) )
           , BuyerPO         = RTRIM ( MAX ( OH.BuyerPO ) )
           , Wave_Descr      = RTRIM ( MAX ( WAVE.Descr ) )
           , PH_EditDate     = MAX ( CONVERT(VARCHAR(19), PH.EditDate, 120) )
           , LpUserdefDate01 = MAX ( CONVERT(VARCHAR(10), LP.LpUserdefDate01, 120) )
           , OrderGroup      = RTRIM ( MAX ( OH.OrderGroup ) )
           , Wavekey         = RTRIM ( MAX ( OH.UserDefine09 ) )
           , Carton_Length   = MAX ( ISNULL ( PAKDTL_DI.Length, PAKDTL_LN.Length ) )
           , Carton_Width    = MAX ( ISNULL ( PAKDTL_DI.Width , PAKDTL_LN.Width  ) )
           , Carton_Height   = MAX ( ISNULL ( PAKDTL_DI.Height, PAKDTL_LN.Height ) )
           , CTN_CBM         = MAX ( ISNULL ( PAKDTL_DI.CBM   , PAKDTL_LN.CBM    ) )
           , CTN_Weight      = MAX ( ISNULL ( PAKDTL_DI.Weight, PAKDTL_LN.Weight ) )
           , PO_Number       = RTRIM ( LA.Lottable03 )

      FROM dbo.ORDERS       OH (NOLOCK)
      JOIN dbo.PACKHEADER   PH (NOLOCK) ON OH.OrderKey = PH.OrderKey
      JOIN dbo.PICKDETAIL   PD (NOLOCK) ON OH.OrderKey = PD.OrderKey
      JOIN dbo.SKU         SKU (NOLOCK) ON PD.Storerkey = SKU.StorerKey AND PD.Sku = SKU.Sku
      JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
      JOIN dbo.WAVE       WAVE (NOLOCK) ON OH.UserDefine09 = WAVE.WaveKey
      LEFT OUTER JOIN dbo.LOADPLAN        LP (NOLOCK) ON (OH.LoadKey = LP.LoadKey)
      LEFT OUTER JOIN #TEMP_PAKDTL_LABELNO PAKDTL_LN ON ( PH.Pickslipno = PAKDTL_LN.PickSlipNo AND PD.CaseID = PAKDTL_LN.LabelNo )
      LEFT OUTER JOIN #TEMP_PAKDTL_DROPID  PAKDTL_DI ON ( PH.Pickslipno = PAKDTL_DI.PickSlipNo AND PD.DropID = PAKDTL_DI.DropID  )

      WHERE @as_mode = '1'
        AND PH.Status = '9'
        AND PD.Qty > 0
        AND OH.StorerKey = @as_storerkey
        AND OH.Loadkey   = @as_loadkey
        AND PH.EditDate >= @as_packcfmdatefrom
        AND PH.EditDate <  @as_packcfmdateto

      GROUP BY OH.Orderkey
             , ISNULL ( PAKDTL_DI.LabelNo , PAKDTL_LN.LabelNo )
             , ISNULL ( PAKDTL_DI.CartonNo, PAKDTL_LN.CartonNo )
             , PD.Sku
             , LA.Lottable08
             , LA.Lottable03

      UNION

      SELECT StorerKey       = RTRIM ( MAX ( OH.StorerKey ) )
           , OrderKey        = OH.Orderkey
           , ConsigneeKey    = RTRIM ( MAX ( OH.ConsigneeKey ) )
           , C_Company       = RTRIM ( MAX ( OH.C_Company ) )
           , C_Address       = MAX ( RTRIM(OH.C_Address1) + ', ' + RTRIM(OH.C_Address2) + ', ' + RTRIM(OH.C_Address3) + ', ' + RTRIM(OH.C_Address4) )
           , C_Country       = RTRIM ( MAX ( OH.C_Country ) )
           , LoadKey         = RTRIM ( MAX ( OH.LoadKey ) )
           , OH_UserDefine02 = RTRIM ( MAX ( OH.UserDefine02 ) )
           , ExternOrderKey  = RTRIM ( MAX ( OH.ExternOrderKey ) )
           , LabelNo         = PAKDTL_LN.LabelNo
           , CartonNo        = PAKDTL_LN.CartonNo
           , SKU             = RTRIM ( PD.Sku )
           , SKUDescr        = RTRIM ( MAX ( SKU.DESCR ) )
           , ALTSKU          = RTRIM ( MAX ( SKU.ALTSKU ) )
           , Style           = RTRIM ( MAX ( SKU.Style ) )
           , Color           = RTRIM ( MAX ( SKU.Color ) )
           , Size            = RTRIM ( MAX ( SKU.Size ) )
           , Qty             = SUM ( PD.Qty )
           , COO             = RTRIM ( PD.RefNo2 )
           , OH_Status       = RTRIM ( MAX ( OH.Status ) )
           , BuyerPO         = RTRIM ( MAX ( OH.BuyerPO ) )
           , Wave_Descr      = RTRIM ( MAX ( WAVE.Descr ) )
           , PH_EditDate     = MAX ( CONVERT(VARCHAR(19), PH.EditDate, 120) )
           , LpUserdefDate01 = MAX ( CONVERT(VARCHAR(10), LP.LpUserdefDate01, 120) )
           , OrderGroup      = RTRIM ( MAX ( OH.OrderGroup ) )
           , Wavekey         = RTRIM ( MAX ( OH.UserDefine09 ) )
           , Carton_Length   = MAX ( PAKDTL_LN.Length )
           , Carton_Width    = MAX ( PAKDTL_LN.Width )
           , Carton_Height   = MAX ( PAKDTL_LN.Height )
           , CTN_CBM         = MAX ( PAKDTL_LN.CBM )
           , CTN_Weight      = MAX ( PAKDTL_LN.Weight )
           , PO_Number       = ''

      FROM dbo.ORDERS     OH (NOLOCK)
      JOIN dbo.PACKHEADER PH (NOLOCK) ON ( OH.OrderKey =  PH.OrderKey )
      JOIN dbo.PACKDETAIL PD (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo )
      JOIN dbo.SKU       SKU (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.Sku )
      JOIN dbo.WAVE     WAVE (NOLOCK) ON ( OH.UserDefine09 = WAVE.WaveKey )
      LEFT OUTER JOIN dbo.LoadPlan       LP (NOLOCK) ON ( OH.LoadKey = LP.LoadKey )
      LEFT OUTER JOIN #TEMP_PAKDTL_LABELNO PAKDTL_LN ON ( PD.PickSlipNo = PAKDTL_LN.PickSlipNo AND PD.LabelNo = PAKDTL_LN.LabelNo )

      WHERE @as_mode = '2'
        AND PH.Status = '9'
        AND PD.Qty > 0
        AND OH.StorerKey = @as_storerkey
        AND OH.Loadkey   = @as_loadkey
        AND PH.EditDate >= @as_packcfmdatefrom
        AND PH.EditDate <  @as_packcfmdateto

      GROUP BY OH.Orderkey
             , PAKDTL_LN.LabelNo
             , PAKDTL_LN.CartonNo
             , PD.SKU
             , PD.RefNo2
   ) X

   ORDER BY [Pack Confirm DateTime]
          , [UA OBD]
          , [LPN]
          , [SKU]
END

GO