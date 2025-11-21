SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_print_wave_pickslip_01                     */
/* Creation Date: 11-Jul-2017                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Wave Pickslip                                                */
/*                                                                       */
/* Called By: RCM - Generate Pickslip in Waveplan                        */
/*            Datawidnow r_hk_print_wave_pickslip_01                     */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_print_wave_pickslip_01] (
       @as_wavekey  NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cDataWidnow    NVARCHAR(40)
         , @n_StartTCnt    INT
         , @c_Storerkey    NVARCHAR(15)
         , @c_PZ_Storerkey NVARCHAR(15)

   SELECT @cDataWidnow  = 'r_hk_print_wave_pickslip_01'
        , @n_StartTCnt  = @@TRANCOUNT

   BEGIN TRY
      EXEC nsp_GetPickSlipWave_08 @as_wavekey
      WITH RESULT SETS NONE
   END TRY
   BEGIN CATCH
   END CATCH

   IF OBJECT_ID('tempdb..#TEMP_PICKDETAIL') IS NOT NULL
      DROP TABLE #TEMP_PICKDETAIL


   SELECT OrderKey      = RTRIM ( OH.OrderKey )
        , Storerkey     = RTRIM( OH.Storerkey )
        , Wavekey       = MAX( RTRIM ( OH.UserDefine09 ) )
        , ExternOrderKey= MAX( RTRIM( OH.ExternOrderKey ) )
        , ConsigneeKey  = MAX( RTRIM ( OH.ConsigneeKey ) )
        , Company       = MAX( RTRIM( STORER.Company ) )
        , C_City        = MAX( RTRIM ( OH.C_City ) )
        , OrderGroup    = MAX( RTRIM( OH.OrderGroup ) )
        , DeliveryDate  = MAX( OH.DeliveryDate )
        , C_Company     = MAX( RTRIM( OH.C_Company ) )
        , Notes2        = MAX( RTRIM ( OH.Notes2 ) )
        , PickHeaderKey = RTRIM ( PH.PickHeaderKey )
        , ItemGroupName = RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ItemGroup') )
        , ItemGroup     = RTRIM(
                            CASE (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ItemGroup')
                            WHEN 'SKUGROUP'  THEN MAX( SKU.SKUGROUP )
                            WHEN 'CLASS'     THEN MAX( SKU.CLASS )
                            WHEN 'ITEMCLASS' THEN MAX( SKU.ITEMCLASS )
                            WHEN 'SUSR1'     THEN MAX( SKU.SUSR1 )
                            WHEN 'SUSR2'     THEN MAX( SKU.SUSR2 )
                            WHEN 'SUSR3'     THEN MAX( SKU.SUSR3 )
                            WHEN 'SUSR4'     THEN MAX( SKU.SUSR4 )
                            WHEN 'SUSR5'     THEN MAX( SKU.SUSR5 )
                            WHEN 'BUSR1'     THEN MAX( SKU.BUSR1 )
                            WHEN 'BUSR2'     THEN MAX( SKU.BUSR2 )
                            WHEN 'BUSR3'     THEN MAX( SKU.BUSR3 )
                            WHEN 'BUSR4'     THEN MAX( SKU.BUSR4 )
                            WHEN 'BUSR5'     THEN MAX( SKU.BUSR5 )
                            WHEN 'BUSR6'     THEN MAX( SKU.BUSR6 )
                            WHEN 'BUSR7'     THEN MAX( SKU.BUSR7 )
                            WHEN 'BUSR8'     THEN MAX( SKU.BUSR8 )
                            WHEN 'BUSR9'     THEN MAX( SKU.BUSR9 )
                            WHEN 'BUSR10'    THEN MAX( SKU.BUSR10)
                            END )
        , Loc           = RTRIM( PD.Loc )
        , LogicalLoc    = MAX( RTRIM( LOC.LogicalLocation ) )
        , ID            = RTRIM( PD.ID )
        , Style         = MAX( RTRIM( SKU.Style ) )
        , Color         = MAX( RTRIM( SKU.Color ) )
        , Size          = MAX( RTRIM( SKU.Size  ) )
        , Sku           = RTRIM( PD.Sku )
        , ALTSKU        = MAX( RTRIM( SKU.ALTSKU ) )
        , RetailSKU     = MAX( RTRIM( SKU.RETAILSKU ) )
        , Qty           = SUM( PD.Qty )
        , Putawayzone   = MAX( RTRIM( LOC.Putawayzone ) )
        , PickType      = CAST( '' AS NVARCHAR(30) )
        , ShowFields    = MAX( RptCfg.ShowFields )
        , datawindow    = @cDataWidnow

   INTO #TEMP_PICKDETAIL

   FROM dbo.ORDERS OH (NOLOCK)
   JOIN dbo.PICKHEADER PH (NOLOCK) ON OH.OrderKey=PH.OrderKey
   JOIN dbo.PICKDETAIL PD (NOLOCK) ON PH.OrderKey=PD.OrderKey
   JOIN dbo.SKU SKU (NOLOCK) ON PD.Storerkey=SKU.StorerKey AND PD.Sku=SKU.Sku
   JOIN dbo.LOC LOC (NOLOCK) ON PD.Loc=LOC.Loc
   JOIN dbo.STORER STORER(NOLOCK) ON OH.StorerKey=STORER.StorerKey

   LEFT OUTER JOIN (
      SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@cDataWidnow AND Short='Y'
   ) RptCfg
   ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1

   LEFT OUTER JOIN (
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@cDataWidnow AND Short='Y'
   ) RptCfg2
   ON RptCfg2.Storerkey=OH.Storerkey AND RptCfg2.SeqNo=1

   WHERE PD.Qty > 0
     AND @as_wavekey <> ''
     AND OH.Userdefine09 = @as_wavekey

   GROUP BY OH.OrderKey
          , OH.Storerkey
          , PH.PickHeaderKey
          , PD.Loc
          , PD.ID
          , PD.Sku


   DECLARE C_TEMP_PICKDETAIL CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey
     FROM #TEMP_PICKDETAIL
    WHERE ','+LTRIM(RTRIM(ISNULL(ShowFields,'')))+',' LIKE '%,PickType,%'
    ORDER BY 1

   OPEN C_TEMP_PICKDETAIL

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_TEMP_PICKDETAIL
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SET @c_PZ_Storerkey = CASE WHEN EXISTS(SELECT TOP 1 1 FROM dbo.CODELKUP (NOLOCK) WHERE Listname='PAZONE_PIK' AND Storerkey=@c_Storerkey)
                                 THEN @c_Storerkey
                                 ELSE ''
                            END
      UPDATE PD
         SET PickType = CASE WHEN PZ.Code IS NULL THEN '2. Replenishment' ELSE '1. Pick' END
        FROM #TEMP_PICKDETAIL PD
        LEFT OUTER JOIN dbo.CODELKUP PZ (NOLOCK) ON PD.Putawayzone=PZ.Code AND PZ.Listname='PAZONE_PIK' AND PZ.Storerkey=@c_PZ_Storerkey AND PZ.Code2=''
       WHERE PD.Storerkey = @c_Storerkey
   END

   CLOSE C_TEMP_PICKDETAIL
   DEALLOCATE C_TEMP_PICKDETAIL


   SELECT * FROM #TEMP_PICKDETAIL
   ORDER BY Wavekey, OrderKey, PickType, ItemGroup, LogicalLoc, Loc, ID, Style, Color, Size, Sku

   DROP TABLE #TEMP_PICKDETAIL


   WHILE @@TRANCOUNT > @n_StartTCnt
   BEGIN
      COMMIT TRAN
   END
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO