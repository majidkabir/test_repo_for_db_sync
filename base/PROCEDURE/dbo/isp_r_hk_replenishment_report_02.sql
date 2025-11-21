SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_replenishment_report_02                    */
/* Creation Date: 23-Aug-2017                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Replenishment Report                                         */
/*                                                                       */
/* Called By: RCM - Dynamic Pick And Replenishment Report in Waveplan    */
/*            Datawidnow r_hk_replenishment_report_02                    */
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

CREATE PROCEDURE [dbo].[isp_r_hk_replenishment_report_02] (
       @as_wavekey  NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cDataWidnow    NVARCHAR(40)
         , @c_Storerkey    NVARCHAR(15)
         , @c_PZ_Storerkey NVARCHAR(15)
         , @n_OrderCount   INT

   IF OBJECT_ID('tempdb..#TEMP_PD_ID') IS NOT NULL
      DROP TABLE #TEMP_PD_ID
   IF OBJECT_ID('tempdb..#TEMP_PICKDETAIL') IS NOT NULL
      DROP TABLE #TEMP_PICKDETAIL
   
   SELECT @cDataWidnow  = 'r_hk_replenishment_report_02'
        , @n_OrderCount = (SELECT COUNT(DISTINCT Orderkey) FROM dbo.ORDERS (NOLOCK) WHERE @as_wavekey<>'' AND Userdefine09=@as_wavekey)

   SELECT DISTINCT
          Storerkey = RTRIM(PD.Storerkey)
        , ID        = RTRIM(PD.ID)
   INTO #TEMP_PD_ID
   FROM dbo.ORDERS     OH (NOLOCK)
   JOIN dbo.PICKDETAIL PD (NOLOCK) ON OH.Orderkey = PD.Orderkey
   WHERE PD.Qty>0 AND PD.ID<>'' AND @as_wavekey<>'' AND Userdefine09=@as_wavekey


   SELECT Orderkey        = RTRIM ( OH.OrderKey )
        , Storerkey       = MAX ( RTRIM ( OH.StorerKey ) )
        , Company         = MAX ( RTRIM ( ST.Company ) )
        , Externorderkey  = MAX ( RTRIM ( OH.ExternOrderKey ) )
        , Wavekey         = MAX ( RTRIM ( OH.UserDefine09 ) )
        , BrandCode       = MAX ( RTRIM ( ISNULL(BRAND.Code,'') ) )
        , BrandDescr      = MAX ( RTRIM ( ISNULL(BRAND.Description,'') ) )
        , Sku             = RTRIM ( PD.Sku )
        , Qty             = SUM ( PD.Qty )
        , ZoneGroupName   = RTRIM( ISNULL((select top 1 b.ColValue
                                       from dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes2)) b
                                       where a.SeqNo=b.SeqNo and a.ColValue='ZoneGroup'),'PutawayZone') )
        , ZoneGroup       = RTRIM( ISNULL(
                                 CASE (select top 1 b.ColValue
                                          from dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes2)) b
                                          where a.SeqNo=b.SeqNo and a.ColValue='ZoneGroup')
                                 WHEN 'LOCATIONTYPE'     THEN MAX(LOC.LocationType)
                                 WHEN 'LOCATIONCATEGORY' THEN MAX(LOC.LocationCategory)
                                 WHEN 'FACILITY'         THEN MAX(LOC.Facility)
                                 WHEN 'PICKZONE'         THEN MAX(LOC.PickZone)
                                 WHEN 'PUTAWAYZONE'      THEN MAX(LOC.PutawayZone)
                                 WHEN 'LOCAISLE'         THEN MAX(LOC.LocAisle)
                                 WHEN 'HOSTWHCODE'       THEN MAX(LOC.HostWHCode)
                                 WHEN 'LOCBAY'           THEN MAX(LOC.LocBay)
                                 WHEN 'LOCATIONROOM'     THEN MAX(LOC.LocationRoom)
                                 WHEN 'LOCATIONGROUP'    THEN MAX(LOC.LocationGroup)
                                 WHEN 'FLOOR'            THEN MAX(LOC.Floor)
                                 ELSE                         MAX(LOC.PutawayZone)
                                 END,'') )
        , ZoneGroupDescr  = CAST('' AS NVARCHAR(60) )
        , Loc             = UPPER( RTRIM ( PD.Loc ) )
        , ID              = UPPER( RTRIM ( PD.ID ) )
        , Descr           = MAX ( RTRIM ( SKU.Descr ) )
        , Style           = MAX ( RTRIM ( SKU.Style ) )
        , Color           = MAX ( RTRIM ( SKU.Color ) )
        , Size            = MAX ( LTRIM(RTRIM ( SKU.Size )) )
        , Putawayzone     = MAX ( RTRIM ( LOC.PutawayZone ) )
        , Logicallocation = MAX ( RTRIM ( LOC.LogicalLocation ) )
        , ItemGroupName   = RTRIM( ISNULL((select top 1 b.ColValue
                                       from dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes2)) b
                                       where a.SeqNo=b.SeqNo and a.ColValue='ItemGroup'),'') )
        , ItemGroup       = RTRIM(
                                 CASE (select top 1 b.ColValue
                                          from dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes2)) b
                                          where a.SeqNo=b.SeqNo and a.ColValue='ItemGroup')
                                 WHEN 'SKUGROUP'  THEN MAX(SKU.SKUGROUP)
                                 WHEN 'CLASS'     THEN MAX(SKU.CLASS)
                                 WHEN 'ITEMCLASS' THEN MAX(SKU.ITEMCLASS)
                                 WHEN 'SUSR1'     THEN MAX(SKU.SUSR1)
                                 WHEN 'SUSR2'     THEN MAX(SKU.SUSR2)
                                 WHEN 'SUSR3'     THEN MAX(SKU.SUSR3)
                                 WHEN 'SUSR4'     THEN MAX(SKU.SUSR4)
                                 WHEN 'SUSR5'     THEN MAX(SKU.SUSR5)
                                 WHEN 'BUSR1'     THEN MAX(SKU.BUSR1)
                                 WHEN 'BUSR2'     THEN MAX(SKU.BUSR2)
                                 WHEN 'BUSR3'     THEN MAX(SKU.BUSR3)
                                 WHEN 'BUSR4'     THEN MAX(SKU.BUSR4)
                                 WHEN 'BUSR5'     THEN MAX(SKU.BUSR5)
                                 WHEN 'BUSR6'     THEN MAX(SKU.BUSR6)
                                 WHEN 'BUSR7'     THEN MAX(SKU.BUSR7)
                                 WHEN 'BUSR8'     THEN MAX(SKU.BUSR8)
                                 WHEN 'BUSR9'     THEN MAX(SKU.BUSR9)
                                 WHEN 'BUSR10'    THEN MAX(SKU.BUSR10)
                                 END )
        , ItemGroupDescr  = CAST('' AS NVARCHAR(60) )
        , ID_SkuCount     = MAX ( IDSOH.ID_SkuCount )
        , ID_Remain       = MAX ( IDSOH.ID_Remain )
        , PickType        = CAST('' AS NVARCHAR(30) )
        , OrderCount      = @n_OrderCount
        , ShowFields      = MAX ( RptCfg.ShowFields )
        , datawindow      = @cDataWidnow

   INTO #TEMP_PICKDETAIL

   FROM dbo.ORDERS       OH (NOLOCK)
   JOIN dbo.PICKDETAIL   PD (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
   JOIN dbo.SKU         SKU (NOLOCK) ON (PD.Storerkey = SKU.StorerKey AND PD.Sku = SKU.Sku)
   JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON (PD.Lot = LA.Lot)
   JOIN dbo.LOC         LOC (NOLOCK) ON (PD.Loc = LOC.Loc)
   JOIN dbo.STORER       ST (NOLOCK) ON (OH.StorerKey = ST.StorerKey)

   LEFT OUTER JOIN dbo.CODELKUP BRAND(NOLOCK) ON BRAND.Listname='BRAND_LOGO' AND OH.Storerkey=BRAND.Storerkey
        AND BRAND.Code = CASE BRAND.UDF01
                            WHEN 'ORDERGROUP'   THEN OH.OrderGroup
                            WHEN 'DOOR'         THEN OH.Door
                            WHEN 'STOP'         THEN OH.Stop
                            WHEN 'USERDEFINE01' THEN OH.Userdefine01
                            WHEN 'USERDEFINE02' THEN OH.Userdefine02
                            WHEN 'USERDEFINE03' THEN OH.Userdefine03
                            WHEN 'USERDEFINE04' THEN OH.Userdefine04
                            WHEN 'USERDEFINE05' THEN OH.Userdefine05
                            WHEN 'USERDEFINE08' THEN OH.Userdefine08
                            WHEN 'USERDEFINE09' THEN OH.Userdefine09
                            WHEN 'USERDEFINE10' THEN OH.Userdefine10
                            WHEN 'LOTTABLE01'   THEN LA.Lottable01
                            WHEN 'LOTTABLE02'   THEN LA.Lottable02
                            WHEN 'LOTTABLE03'   THEN LA.Lottable03
                            WHEN 'SKUGROUP'     THEN SKU.SKUGROUP
                            WHEN 'CLASS'        THEN SKU.CLASS
                            WHEN 'ITEMCLASS'    THEN SKU.ITEMCLASS
                            WHEN 'SUSR1'        THEN SKU.SUSR1
                            WHEN 'SUSR2'        THEN SKU.SUSR2
                            WHEN 'SUSR3'        THEN SKU.SUSR3
                            WHEN 'SUSR4'        THEN SKU.SUSR4
                            WHEN 'SUSR5'        THEN SKU.SUSR5
                            WHEN 'BUSR1'        THEN SKU.BUSR1
                            WHEN 'BUSR2'        THEN SKU.BUSR2
                            WHEN 'BUSR3'        THEN SKU.BUSR3
                            WHEN 'BUSR4'        THEN SKU.BUSR4
                            WHEN 'BUSR5'        THEN SKU.BUSR5
                            WHEN 'BUSR6'        THEN SKU.BUSR6
                            WHEN 'BUSR7'        THEN SKU.BUSR7
                            WHEN 'BUSR8'        THEN SKU.BUSR8
                            WHEN 'BUSR9'        THEN SKU.BUSR9
                            WHEN 'BUSR10'       THEN SKU.BUSR10
                         END
   LEFT OUTER JOIN (
      SELECT Storerkey    = a.Storerkey
           , ID           = UPPER(a.ID)
           , ID_Qty       = SUM ( a.Qty )
           , ID_Allocated = SUM ( a.QtyAllocated )
           , ID_Picked    = SUM ( a.QtyPicked )
           , ID_Remain    = SUM ( a.Qty - a.QtyAllocated - a.QtyPicked )
           , ID_SkuCount  = COUNT(DISTINCT a.Sku)
      FROM dbo.LOTxLOCxID a (NOLOCK)
      JOIN #TEMP_PD_ID b ON a.Storerkey=b.Storerkey AND a.ID=b.ID
      WHERE a.ID<>'' AND a.Qty>0
      GROUP BY a.Storerkey, a.ID
   ) IDSOH ON (PD.Storerkey = IDSOH.Storerkey AND PD.ID = IDSOH.ID)

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

   WHERE PD.Qty>0 AND @as_wavekey<>'' AND OH.UserDefine09 = @as_wavekey

   GROUP BY OH.OrderKey
          , PD.Sku
          , PD.Loc
          , PD.ID


   DECLARE C_TEMP_PICKDETAIL CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey
     FROM #TEMP_PICKDETAIL
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
         SET PickType       = CASE WHEN PZ.Code IS NULL THEN 'Replenishment' ELSE 'Pick' END
           , ZoneGroupDescr = RTRIM( ISNULL( (select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(RptCfg1.Delim,RptCfg1.Notes) a, dbo.fnc_DelimSplit(RptCfg1.Delim,RptCfg1.Notes2) b
                                 where a.SeqNo=b.SeqNo and a.ColValue=PD.ZoneGroup)
                               , RptCfg1.DftValue ) )
           , ItemGroupDescr = RTRIM( ISNULL( (select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(RptCfg2.Delim,RptCfg2.Notes) a, dbo.fnc_DelimSplit(RptCfg2.Delim,RptCfg2.Notes2) b
                                 where a.SeqNo=b.SeqNo and a.ColValue=PD.ItemGroup)
                               , RptCfg2.DftValue ) )
      FROM #TEMP_PICKDETAIL PD
      
      LEFT OUTER JOIN dbo.CODELKUP PZ (NOLOCK) ON PD.Putawayzone=PZ.Code AND PZ.Listname='PAZONE_PIK' AND PZ.Storerkey=@c_PZ_Storerkey AND PZ.Code2=''
      
      LEFT OUTER JOIN (
         SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01)), DftValue = RTRIM(UDF03)
              , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
           FROM CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPCODE' AND Long=@cDataWidnow AND Short='Y' AND UDF02='ZONEGROUP'
      ) RptCfg1
      ON RptCfg1.Storerkey=PD.Storerkey AND RptCfg1.SeqNo=1
      
      LEFT OUTER JOIN (
         SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01)), DftValue = RTRIM(UDF03)
              , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
           FROM CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPCODE' AND Long=@cDataWidnow AND Short='Y' AND UDF02='ITEMGROUP'
      ) RptCfg2
      ON RptCfg2.Storerkey=PD.Storerkey AND RptCfg2.SeqNo=1
      
      WHERE PD.Storerkey = @c_Storerkey
   END

   CLOSE C_TEMP_PICKDETAIL
   DEALLOCATE C_TEMP_PICKDETAIL


   SELECT * FROM #TEMP_PICKDETAIL
   WHERE PickType = 'Replenishment'
   ORDER BY Wavekey, ZoneGroup, Logicallocation, Loc, Id, Orderkey, Style, Color, size

   DROP TABLE #TEMP_PICKDETAIL
   DROP TABLE #TEMP_PD_ID
END

GO