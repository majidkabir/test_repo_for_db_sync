SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_picking_control_list_09                    */
/* Creation Date: 19-Jan-2021                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Carton Label                                                 */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_picking_control_list_09     */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 23/03/2022   ML       1.1  Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_picking_control_list_09] (
       @as_Storerkey        NVARCHAR(15)
     , @as_deliverydatefrom NVARCHAR(20)
     , @as_deliverydateto   NVARCHAR(20)
     , @as_wavekey          NVARCHAR(4000)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      LFL_Company, CustomerGroupCode, PageBreakValue, ShipTo, ExternOrderkey
   [MAPVALUE]
   [SHOWFIELD]
   [SQLJOIN]
*/
   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY') IS NOT NULL
      DROP TABLE #TEMP_FINALORDERKEY
   IF OBJECT_ID('tempdb..#TEMP_PIKDT') IS NOT NULL
      DROP TABLE #TEMP_PIKDT

   DECLARE @c_ExecStatements   NVARCHAR(MAX)  = ''
         , @c_ExecArguments    NVARCHAR(MAX)  = ''
         , @c_DataWindow       NVARCHAR(40)   = 'r_hk_picking_control_list_09'
         , @d_DeliveryDateFrom DATE
         , @d_DeliveryDateTo   DATE
         , @c_LFL_CompanyExp   NVARCHAR(MAX)
         , @c_CustGrpCodeExp   NVARCHAR(MAX)
         , @c_PageBrkValueExp  NVARCHAR(MAX)
         , @c_ShipToExp        NVARCHAR(MAX)
         , @c_ExtOrderkeyExp   NVARCHAR(MAX)


   IF ISDATE(@as_deliverydatefrom) = 1
      SET @d_DeliveryDateFrom = CONVERT(DATE, @as_deliverydatefrom)

   IF ISDATE(@as_deliverydateto) = 1
      SET @d_DeliveryDateTo   = DATEADD(DAY, 1, CONVERT(DATE, @as_deliverydateto))


   CREATE TABLE #TEMP_PIKDT (
        Storerkey         NVARCHAR(15)  NULL
      , Facility          NVARCHAR(5)   NULL
      , Loadkey           NVARCHAR(10)  NULL
      , Wavekey           NVARCHAR(10)  NULL
      , PickslipNo        NVARCHAR(20)  NULL
      , Route             NVARCHAR(10)  NULL
      , PutawayZone       NVARCHAR(10)  NULL
      , DeliveryDate      DATE          NULL
      , LFL_Company       NVARCHAR(500) NULL
      , CustomerGroupCode NVARCHAR(500) NULL
      , PageBreakValue    NVARCHAR(500) NULL
      , ShipTo            NVARCHAR(500) NULL
      , ExternOrderKey    NVARCHAR(500) NULL
      , Qty               INT           NULL
   )

   SELECT @c_LFL_CompanyExp   = ''
        , @c_CustGrpCodeExp   = ''
        , @c_PageBrkValueExp  = ''
        , @c_ShipToExp        = ''
        , @c_ExtOrderkeyExp   = ''

   SELECT TOP 1
          @c_LFL_CompanyExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='LFL_Company')), '' )
        , @c_CustGrpCodeExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='CustomerGroupCode')), '' )
        , @c_PageBrkValueExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='PageBreakValue')), '' )
        , @c_ShipToExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='ShipTo')), '' )
        , @c_ExtOrderkeyExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='ExternOrderkey')), '' )
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
      AND Storerkey = @as_Storerkey
    ORDER BY Code2

   ----------
   SET @c_ExecStatements = N'INSERT INTO #TEMP_PIKDT'
       +' (Storerkey, Facility, Loadkey, Wavekey, PickslipNo, Route, PutawayZone, DeliveryDate'
       + ', LFL_Company, CustomerGroupCode, PageBreakValue, ShipTo, ExternOrderKey, Qty)'
       + 'SELECT ISNULL(RTRIM( OH.StorerKey ),'''')'
       +      ', ISNULL(RTRIM( LOC.Facility ),'''')'
       +      ', ISNULL(RTRIM( UPPER( OH.LoadKey ) ),'''')'
       +      ', ISNULL(RTRIM( OH.UserDefine09 ),'''')'
       +      ', ISNULL(RTRIM( UPPER( PH.PickHeaderKey ) ),'''')'
       +      ', ISNULL(RTRIM( OH.Route ),'''')'
       +      ', ISNULL(RTRIM( LOC.PutawayZone ),'''')'
       +      ', CONVERT(DATE, OH.DeliveryDate)'
   SET @c_ExecStatements = @c_ExecStatements
       +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LFL_CompanyExp   ,'')<>'' THEN @c_LFL_CompanyExp    ELSE 'LFL.Company'          END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
       +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CustGrpCodeExp   ,'')<>'' THEN @c_CustGrpCodeExp    ELSE 'ST.CustomerGroupCode' END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
       +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PageBrkValueExp  ,'')<>'' THEN @c_PageBrkValueExp   ELSE 'CONVERT(NVARCHAR(10),ISNULL(PH.PickHeaderKey,''''))+CONVERT(NVARCHAR(10),ISNULL(OH.Loadkey,''''))' END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
       +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ShipToExp        ,'')<>'' THEN @c_ShipToExp
                                  ELSE 'RTRIM(RTRIM(RTRIM(RTRIM(RTRIM(TRIM(ISNULL(OH.Consigneekey,''''))+'' ''+TRIM(ISNULL(OH.C_Address1,'''')))+'' ''+TRIM(ISNULL(OH.C_Address2,'''')))'
                                     + '+'' ''+TRIM(ISNULL(OH.C_Address3,'''')))+'' ''+TRIM(ISNULL(OH.C_Address4,'''')))+'' ''+TRIM(ISNULL(OH.C_City,'''')))'
                                  END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
       +      ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExtOrderkeyExp   ,'')<>'' THEN @c_ExtOrderkeyExp    ELSE 'CASE WHEN X.NoOfOrder=1 THEN OH.ExternOrderkey END' END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
       +      ', PD.Qty'
   SET @c_ExecStatements = @c_ExecStatements
       +' FROM dbo.ORDERS     OH (NOLOCK)'
       +' JOIN dbo.PICKDETAIL PD (NOLOCK) ON OH.OrderKey = PD.OrderKey'
       +' JOIN dbo.LOC        LOC(NOLOCK) ON PD.Loc = LOC.Loc'
       +' JOIN dbo.LoadPlan   LP (NOLOCK) ON OH.LoadKey = LP.LoadKey'
       +' JOIN dbo.STORER     ST (NOLOCK) ON OH.Storerkey = ST.Storerkey'
       +' LEFT JOIN ('
       +   ' SELECT LoadKey    = OH.LoadKey'
       +         ', NoOfOrder  = COUNT( DISTINCT OH.Orderkey )'
       +   ' FROM dbo.ORDERS      OH (NOLOCK)'
       +   ' JOIN dbo.PICKDETAIL  PD (NOLOCK) ON OH.OrderKey = PD.OrderKey'
       +   ' JOIN dbo.LOC         LOC(NOLOCK) ON PD.Loc = LOC.Loc'
       +   ' WHERE OH.STATUS < ''5'' AND OH.StorerKey = @as_Storerkey'
       +   ' GROUP BY OH.LoadKey'
       + ') X ON OH.loadkey = X.LoadKey'
       +' LEFT JOIN dbo.PICKHEADER PH (NOLOCK) ON OH.LoadKey = PH.ExternOrderKey AND ISNULL(PH.Orderkey,'''') = '''' AND PH.Zone=''7'''
       +' LEFT JOIN dbo.STORER     LFL(NOLOCK) ON LFL.Storerkey = ''11301'''
   SET @c_ExecStatements = @c_ExecStatements
       +' WHERE OH.StorerKey = @as_Storerkey'
       +  ' AND OH.STATUS < ''5'''
       +  ' AND LP.LoadPickMethod = ''C'''
       +  ' AND OH.LoadKey <> '''''

   IF ISNULL(@as_deliverydatefrom,'')='' AND ISNULL(@as_wavekey,'')=''
      SET @c_ExecStatements = @c_ExecStatements
          +' AND 1=2'
   ELSE
   BEGIN
      IF ISNULL(@as_deliverydatefrom,'')<>''
         SET @c_ExecStatements = @c_ExecStatements
             +' AND OH.DeliveryDate >= @d_DeliveryDateFrom AND OH.DeliveryDate < @d_DeliveryDateTo'

      IF ISNULL(@as_wavekey,'')<>''
         SET @c_ExecStatements = @c_ExecStatements
             +' AND OH.UserDefine09 IN (SELECT DISTINCT LTRIM(value) FROM STRING_SPLIT(REPLACE(@as_wavekey,char(13)+char(10),'',''),'','') WHERE value<>'''' )'
   END

   SET @c_ExecArguments = N'@c_DataWindow        NVARCHAR(40)'
                        + ',@as_Storerkey        NVARCHAR(15)'
                        + ',@d_DeliveryDateFrom  DATE'
                        + ',@d_DeliveryDateTo    DATE'
                        + ',@as_wavekey          NVARCHAR(4000)'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @c_DataWindow
                    , @as_Storerkey
                    , @d_DeliveryDateFrom
                    , @d_DeliveryDateTo
                    , @as_wavekey



   SELECT StorerKey         = PIKDT.StorerKey
        , Facility          = PIKDT.Facility
        , DeliveryDate      = PIKDT.DeliveryDate
        , Wavekey           = PIKDT.Wavekey
        , PickslipNo        = PIKDT.PickslipNo
        , Route             = PIKDT.Route
        , PutawayZone       = PIKDT.PutawayZone
        , Qty               = SUM( PIKDT.Qty )
        , LoadKey           = PIKDT.LoadKey
        , LFL_Company       = MAX( PIKDT.LFL_Company )
        , datawindow        = @c_DataWindow
        , CustomerGroupCode = MAX( PIKDT.CustomerGroupCode )
        , PageBreakValue    = PIKDT.PageBreakValue
        , ExternOrderkey    = PIKDT.ExternOrderkey
        , ShipTo            = MAX( PIKDT.ShipTo )
   FROM #TEMP_PIKDT PIKDT
   GROUP BY PIKDT.StorerKey
          , PIKDT.Facility
          , PIKDT.DeliveryDate 
          , PIKDT.Wavekey
          , PIKDT.PickslipNo
          , PIKDT.Route
          , PIKDT.PutawayZone
          , PIKDT.LoadKey
          , PIKDT.PageBreakValue
          , PIKDT.ExternOrderkey
   ORDER BY Storerkey, Facility, PageBreakValue, PutawayZone, Loadkey
END

GO