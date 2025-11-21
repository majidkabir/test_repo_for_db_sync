SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_r_hk_carton_label_04                            */  
/* Creation Date: 21-Nov-2017                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Michael Lam (HK LIT)                                      */  
/*                                                                       */  
/* Purpose: Pre-print Carton Label                                       */  
/*                                                                       */  
/* Called By: Report Module. Datawidnow r_hk_carton_label_04             */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 23/11/2017   ML       1.1  Fix duplicate order issue                  */  
/* 11/05/2018   ML       1.2  Fix DropIDPrefix no default value issue    */  
/* 07/03/2019   ML       1.3  Change to use SEQKey table for SeqTbl      */  
/* 20/10/2021   ML       1.4  WMS-18214 Add OH.Userdefine05              */  
/* 23/03/2022   ML       1.5  Add NULL to Temp Table                     */  
/*************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_r_hk_carton_label_04] (  
       @as_storerkey       NVARCHAR(15)  
     , @as_wavekey         NVARCHAR(10)  
     , @as_loadkey         NVARCHAR(10)  
     , @as_pickslipno      NVARCHAR(4000)  
     , @as_externorderkey  NVARCHAR(4000)  
     , @as_orderkey        NVARCHAR(4000)  
     , @as_putawayzone     NVARCHAR(4000)  
     , @as_cartonnofrom    NVARCHAR(10) = ''  
     , @as_cartonnoto      NVARCHAR(10) = ''  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
/* CODELKUP.REPORTCFG  
   [MAPFIELD]  
      DocNumber, C_Company, C_Address1, C_Address2, C_Address3, C_Address4, Notes, Notes2  
      PickZone, ShoeGroup, CartonCBM, DropIDPrefix, ConsigneePrefix  
   [MAPVALUE]  
      T_DocNumber  
   [SHOWFIELD]  
   [SQLJOIN]  
*/  
  
   IF OBJECT_ID('tempdb..#TEMP_PICKSLIPNO') IS NOT NULL  
      DROP TABLE #TEMP_PICKSLIPNO  
   IF OBJECT_ID('tempdb..#TEMP_ORDERKEY') IS NOT NULL  
      DROP TABLE #TEMP_ORDERKEY  
   IF OBJECT_ID('tempdb..#TEMP_EXTERNORDERKEY') IS NOT NULL  
      DROP TABLE #TEMP_EXTERNORDERKEY  
   IF OBJECT_ID('tempdb..#TEMP_PUTAWAYZONE') IS NOT NULL  
      DROP TABLE #TEMP_PUTAWAYZONE  
   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY') IS NOT NULL  
      DROP TABLE #TEMP_FINALORDERKEY  
   IF OBJECT_ID('tempdb..#TEMP_ORDET') IS NOT NULL  
      DROP TABLE #TEMP_ORDET  
   IF OBJECT_ID('tempdb..#TEMP_ZONECOUNT') IS NOT NULL  
      DROP TABLE #TEMP_ZONECOUNT  
   IF OBJECT_ID('tempdb..#TEMP_ORDET2') IS NOT NULL  
      DROP TABLE #TEMP_ORDET2  
  
   DECLARE @c_DataWidnow         NVARCHAR(40)  
         , @c_DocNumberExp       NVARCHAR(4000)  
         , @c_C_CompanyExp       NVARCHAR(4000)  
         , @c_C_Address1Exp      NVARCHAR(4000)  
         , @c_C_Address2Exp      NVARCHAR(4000)  
         , @c_C_Address3Exp      NVARCHAR(4000)  
         , @c_C_Address4Exp      NVARCHAR(4000)  
         , @c_NotesExp           NVARCHAR(4000)  
         , @c_Notes2Exp          NVARCHAR(4000)  
         , @c_PickZoneExp        NVARCHAR(4000)  
         , @c_ShoeGroupExp       NVARCHAR(4000)  
         , @c_CartonCBM          NVARCHAR(4000)  
       , @c_DropIDPrefix       NVARCHAR(30)  
         , @c_ConsigneePrefix    NVARCHAR(15)  
         , @n_PickslipNoCnt      INT  
         , @n_OrderkeyCnt        INT  
         , @n_ExternOrderkeyCnt  INT  
         , @n_PutawayZoneCnt     INT  
         , @c_ExecStatements     NVARCHAR(MAX)  
         , @c_ExecArguments      NVARCHAR(MAX)  
         , @c_JoinClause         NVARCHAR(4000)  
         , @n_CartonNoFrom       INT  
         , @n_CartonNoTo         INT  
  
  
   SELECT @c_DataWidnow = 'r_hk_carton_label_04'  
        , @n_CartonNoFrom = ISNULL( IIF(ISNULL(@as_cartonnofrom,'')='', 0, TRY_PARSE(@as_cartonnofrom AS FLOAT)), 0 )  
        , @n_CartonNoTo   = ISNULL( IIF(ISNULL(@as_cartonnoto  ,'')='', 0, TRY_PARSE(@as_cartonnoto   AS FLOAT)), 0 )  
  
   CREATE TABLE #TEMP_ORDET (  
        Orderkey        NVARCHAR(10)  NULL  
      , Storerkey       NVARCHAR(15)  NULL  
      , PickslipNo      NVARCHAR(18)  NULL  
      , DocNumber       NVARCHAR(500) NULL  
      , C_Company       NVARCHAR(500) NULL  
      , C_Address1      NVARCHAR(500) NULL  
      , C_Address2      NVARCHAR(500) NULL  
      , C_Address3      NVARCHAR(500) NULL  
      , C_Address4      NVARCHAR(500) NULL  
      , Notes           NVARCHAR(500) NULL  
      , Notes2          NVARCHAR(500) NULL  
      , PickZone        NVARCHAR(500) NULL  
      , ShoeGroup       NVARCHAR(500) NULL  
      , CartonCBM       FLOAT         NULL  
      , Qty             INT           NULL  
      , StdCube         FLOAT         NULL  
      , ConsolPick      NVARCHAR(1)   NULL  
      , DocKey          NVARCHAR(10)  NULL  
      , FirstOrderkey   NVARCHAR(10)  NULL  
   )  
  
  
   -- PickslipNo List  
   SELECT SeqNo    = MIN(SeqNo)  
        , ColValue = LTRIM(RTRIM(ColValue))  
     INTO #TEMP_PICKSLIPNO  
     FROM dbo.fnc_DelimSplit(',',REPLACE(@as_pickslipno,CHAR(13)+CHAR(10),','))  
    WHERE ColValue<>''  
    GROUP BY LTRIM(RTRIM(ColValue))  
  
   SET @n_PickslipNoCnt = @@ROWCOUNT  
  
   -- Orderkey List  
   SELECT SeqNo    = MIN(SeqNo)  
        , ColValue = LTRIM(RTRIM(ColValue))  
     INTO #TEMP_ORDERKEY  
     FROM dbo.fnc_DelimSplit(',',replace(@as_orderkey,char(13)+char(10),','))  
    WHERE ColValue<>''  
    GROUP BY LTRIM(RTRIM(ColValue))  
  
   SET @n_OrderkeyCnt = @@ROWCOUNT  
  
   -- ExternOrderkey List  
   SELECT SeqNo    = MIN(SeqNo)  
        , ColValue = LTRIM(RTRIM(ColValue))  
     INTO #TEMP_EXTERNORDERKEY  
     FROM dbo.fnc_DelimSplit(',',replace(@as_externorderkey,char(13)+char(10),','))  
    WHERE ColValue<>''  
    GROUP BY LTRIM(RTRIM(ColValue))  
  
   SET @n_ExternOrderkeyCnt = @@ROWCOUNT  
  
   -- PutawayZone List  
   SELECT SeqNo    = MIN(SeqNo)  
        , ColValue = LTRIM(RTRIM(ColValue))  
     INTO #TEMP_PUTAWAYZONE  
     FROM dbo.fnc_DelimSplit(',',replace(@as_putawayzone,char(13)+char(10),','))  
    WHERE ColValue<>''  
    GROUP BY LTRIM(RTRIM(ColValue))  
  
   SET @n_PutawayZoneCnt = @@ROWCOUNT  
  
  
   -- Final Orderkey, PickslipNo List  
   SELECT Orderkey       = OH.Orderkey  
        , PickslipNo     = MAX( PH.PickheaderKey )  
        , Loadkey        = MAX( OH.Loadkey )  
        , ConsolPick     = 'N'  
        , DocKey         = MAX( OH.Orderkey )  
     INTO #TEMP_FINALORDERKEY  
     FROM dbo.ORDERS     OH (NOLOCK)  
     JOIN dbo.PICKHEADER PH (NOLOCK) ON OH.Orderkey = PH.Orderkey AND OH.Orderkey<>''  
    WHERE ( OH.Status BETWEEN '1' AND '9' )  
      AND ( OH.Storerkey = @as_storerkey )  
      AND ( @as_wavekey<>'' OR @as_loadkey<>'' OR @n_PickslipNoCnt>0 OR @n_ExternOrderkeyCnt>0 OR @n_OrderkeyCnt>0 )  
      AND ( ISNULL(@as_wavekey,'')='' OR (@as_wavekey<>'' AND OH.Userdefine09 = @as_wavekey ) )  
      AND ( ISNULL(@as_loadkey,'')='' OR (@as_loadkey<>'' AND OH.LoadKey = @as_loadkey ) )  
      AND (@n_PickslipNoCnt=0 OR PH.PickheaderKey IN (SELECT ColValue FROM #TEMP_PICKSLIPNO) )  
      AND (@n_ExternOrderkeyCnt=0 OR OH.ExternOrderKey IN (SELECT ColValue FROM #TEMP_EXTERNORDERKEY ) )  
      AND (@n_OrderkeyCnt=0 OR OH.OrderKey IN (SELECT ColValue FROM #TEMP_ORDERKEY ) )  
    GROUP BY OH.Orderkey  
  
   INSERT INTO #TEMP_FINALORDERKEY  
   SELECT Orderkey       = OH.Orderkey  
        , PickslipNo     = MAX( PH.PickheaderKey )  
        , Loadkey        = MAX( OH.Loadkey )  
        , ConsolPick     = MAX( CASE WHEN ISNULL(OH.Userdefine09,'')<>'' THEN 'Y' ELSE 'N' END )  
        , DocKey         = MAX( CASE WHEN ISNULL(OH.Userdefine09,'')<>'' THEN OH.Loadkey ELSE OH.Orderkey END )  
     FROM dbo.ORDERS     OH (NOLOCK)  
     JOIN dbo.PICKHEADER PH (NOLOCK) ON OH.Loadkey = PH.ExternOrderkey AND ISNULL(OH.Loadkey,'')<>'' AND ISNULL(PH.Orderkey,'')=''  
  LEFT JOIN #TEMP_FINALORDERKEY FOK ON OH.Orderkey = FOK.Orderkey  
    WHERE ( OH.Status BETWEEN '1' AND '9' )  
      AND ( OH.Storerkey = @as_storerkey )  
      AND ( @as_wavekey<>'' OR @as_loadkey<>'' OR @n_PickslipNoCnt>0 OR @n_ExternOrderkeyCnt>0 OR @n_OrderkeyCnt>0 )  
      AND ( ISNULL(@as_wavekey,'')='' OR (@as_wavekey<>'' AND OH.Userdefine09 = @as_wavekey ) )  
      AND ( ISNULL(@as_loadkey,'')='' OR (@as_loadkey<>'' AND OH.LoadKey = @as_loadkey ) )  
      AND (@n_PickslipNoCnt=0 OR PH.PickheaderKey IN (SELECT ColValue FROM #TEMP_PICKSLIPNO) )  
      AND (@n_ExternOrderkeyCnt=0 OR OH.ExternOrderKey IN (SELECT ColValue FROM #TEMP_EXTERNORDERKEY ) )  
      AND (@n_OrderkeyCnt=0 OR OH.OrderKey IN (SELECT ColValue FROM #TEMP_ORDERKEY ) )  
      AND FOK.Orderkey IS NULL  
    GROUP BY OH.Orderkey  
  
  
   SELECT @c_DocNumberExp       = ''  
        , @c_C_CompanyExp       = ''  
        , @c_C_Address1Exp      = ''  
        , @c_C_Address2Exp      = ''  
        , @c_C_Address3Exp      = ''  
        , @c_C_Address4Exp      = ''  
        , @c_NotesExp           = ''  
        , @c_Notes2Exp          = ''  
        , @c_PickZoneExp        = ''  
        , @c_ShoeGroupExp       = ''  
        , @c_CartonCBM          = ''  
        , @c_DropIDPrefix       = NULL  
        , @c_ConsigneePrefix    = ''  
        , @c_JoinClause         = ''  
  
  
   SELECT TOP 1  
          @c_JoinClause  = Notes  
     FROM dbo.CodeLkup (NOLOCK)  
    WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWidnow AND Short='Y'  
      AND Storerkey = @as_storerkey  
    ORDER BY Code2  
  
  
   SELECT TOP 1  
          @c_DocNumberExp       = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='DocNumber')), '' )  
        , @c_C_CompanyExp       = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='C_Company')), '' )  
        , @c_C_Address1Exp      = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='C_Address1')), '' )  
        , @c_C_Address2Exp      = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='C_Address2')), '' )  
        , @c_C_Address3Exp      = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='C_Address3')), '' )  
        , @c_C_Address4Exp      = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                 where a.SeqNo=b.SeqNo and a.ColValue='C_Address4')), '' )  
        , @c_NotesExp           = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='Notes')), '' )  
        , @c_Notes2Exp          = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='Notes2')), '' )  
        , @c_PickZoneExp        = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='PickZone')), '' )  
        , @c_ShoeGroupExp       = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='ShoeGroup')), '' )  
        , @c_CartonCBM          = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='CartonCBM')), '' )  
        , @c_DropIDPrefix       = RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='DropIDPrefix'))  
        , @c_ConsigneePrefix    = ISNULL(RTRIM((select top 1 b.ColValue  
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                  where a.SeqNo=b.SeqNo and a.ColValue='ConsigneePrefix')), '' )  
     FROM dbo.CodeLkup (NOLOCK)  
    WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWidnow AND Short='Y'  
      AND Storerkey = @as_storerkey  
    ORDER BY Code2  
  
  
   ----------  
   SET @c_ExecStatements = N'INSERT INTO #TEMP_ORDET'  
       +' (Orderkey, Storerkey, PickslipNo, DocNumber, C_Company,'  
       + ' C_Address1, C_Address2, C_Address3, C_Address4, Notes,'  
       + ' Notes2, PickZone, ShoeGroup, CartonCBM, Qty,'  
       + ' StdCube, ConsolPick, DocKey, FirstOrderkey)'  
       +' SELECT OH.OrderKey'  
            + ', OH.Storerkey'  
            + ', FOK.PickslipNo'  
            + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DocNumberExp ,'')<>'' THEN @c_DocNumberExp  ELSE 'FOK.DocKey'      END + '),'''')'  
            + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_CompanyExp ,'')<>'' THEN @c_C_CompanyExp  ELSE 'OH.C_Company'    END + '),'''')'  
            + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address1Exp,'')<>'' THEN @c_C_Address1Exp ELSE 'OH.C_Address1'   END + '),'''')'  
            + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address2Exp,'')<>'' THEN @c_C_Address2Exp ELSE 'OH.C_Address2'   END + '),'''')'  
            + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address3Exp,'')<>'' THEN @c_C_Address3Exp ELSE 'OH.C_Address3'   END + '),'''')'  
            + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address4Exp,'')<>'' THEN @c_C_Address4Exp ELSE 'OH.C_Address4'   END + '),'''')'  
            + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_NotesExp     ,'')<>'' THEN @c_NotesExp      ELSE 'OH.Notes'        END + '),'''')'  
            + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Notes2Exp    ,'')<>'' THEN @c_Notes2Exp     ELSE 'OH.Notes2'       END + '),'''')'  
            + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PickZoneExp  ,'')<>'' THEN @c_PickZoneExp   ELSE ''''''            END + '),'''')'  
            + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ShoeGroupExp ,'')<>'' THEN @c_ShoeGroupExp  ELSE ''''''            END + '),'''')'  
            + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CartonCBM    ,'')<>'' THEN @c_CartonCBM     ELSE '0.047'           END + '),'''')'  
            + ', PD.Qty'  
            + ', SKU.StdCube'  
            + ', FOK.ConsolPick'  
            + ', FOK.DocKey'  
            + ', FIRST_VALUE(FOK.Orderkey) OVER(PARTITION BY FOK.DocKey ORDER BY FOK.Orderkey)'  
       +' FROM dbo.ORDERS       OH (NOLOCK)'  
       +' JOIN #TEMP_FINALORDERKEY FOK ON OH.Orderkey=FOK.Orderkey'  
       +' JOIN dbo.ORDERDETAIL  OD (NOLOCK) ON OH.Orderkey=OD.Orderkey'  
       +' JOIN dbo.PICKDETAIL   PD (NOLOCK) ON OD.Orderkey=PD.Orderkey AND OD.OrderLineNumber=PD.OrderLineNumber'  
       +' JOIN dbo.SKU         SKU (NOLOCK) ON PD.StorerKey=SKU.StorerKey AND PD.Sku=SKU.Sku'  
       +' JOIN dbo.PACK       PACK (NOLOCK) ON SKU.Packkey=PACK.Packkey'  
       +' JOIN dbo.LOC         LOC (NOLOCK) ON PD.Loc=LOC.Loc'  
       +' JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON PD.Lot=LA.Lot'  
       + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END  
       +' WHERE PD.Qty > 0'  
       + CASE WHEN @n_PutawayZoneCnt>0 THEN ' AND LOC.PutawayZone IN (SELECT ColValue FROM #TEMP_PUTAWAYZONE )' ELSE '' END  
  
   SET @c_ExecArguments = N''  
  
   EXEC sp_ExecuteSql @c_ExecStatements  
                    , @c_ExecArguments  
  
  
   -----------------------  
   SELECT DocKey  
        , ZoneCount = COUNT(DISTINCT PickZone)  
     INTO #TEMP_ZONECOUNT  
     FROM #TEMP_ORDET  
    GROUP BY DocKey  
  
   -----------------------  
   UPDATE a  
      SET C_Company    = b.C_Company  
        , C_Address1   = b.C_Address1  
        , C_Address2   = b.C_Address2  
        , C_Address3   = b.C_Address3  
        , C_Address4   = b.C_Address4  
        , Notes        = b.Notes  
        , Notes2       = b.Notes2  
     FROM #TEMP_ORDET a  
     JOIN (  
        SELECT *, SeqNo = ROW_NUMBER() OVER(PARTITION BY DocKey ORDER BY Orderkey)  
          FROM #TEMP_ORDET  
     ) b ON a.DocKey = b.DocKey AND b.SeqNo = 1  
  
  
   ------------------------  
   SELECT Storerkey         = RTRIM( UPPER( ORDET.Storerkey ) )  
        , DocKey            = RTRIM( ISNULL( ORDET.DocKey, '' ) )  
        , DocNumber         = RTRIM( ISNULL( MAX( ORDET.DocNumber ), '') )  
        , PickSlipNo        = RTRIM( ISNULL( MAX( ORDET.PickSlipNo ), '') )  
        , Orderkey          = RTRIM( MAX( ORDET.FirstOrderkey ) )  
        , Externorderkey    = RTRIM( ISNULL( MAX( OH.ExternOrderKey ), '') )  
        , Wavekey           = RTRIM( ISNULL( MAX( OH.Userdefine09 ), '') )  
        , Loadkey           = RTRIM( ISNULL( MAX( OH.Loadkey ), '') )  
        , Deliverydate      = MAX ( OH.DeliveryDate )  
        , ConsigneeKey      = RTRIM( ISNULL( MAX( CASE WHEN LEFT(OH.ConsigneeKey, LEN(@c_ConsigneePrefix))=@c_ConsigneePrefix  
                                     THEN SUBSTRING(OH.ConsigneeKey, LEN(@c_ConsigneePrefix)+1, LEN(OH.ConsigneeKey))  
                                     ELSE OH.ConsigneeKey END ), '' ) )  
        , C_Company         = RTRIM( ISNULL( MAX( ORDET.C_Company ), '' ) )  
        , C_Address1        = RTRIM( ISNULL( MAX( ORDET.C_Address1 ), '' ) )  
        , C_Address2        = RTRIM( ISNULL( MAX( ORDET.C_Address2 ), '' ) )  
        , C_Address3        = RTRIM( ISNULL( MAX( ORDET.C_Address3 ), '' ) )  
        , C_Address4        = RTRIM( ISNULL( MAX( ORDET.C_Address4 ), '' ) )  
        , Notes             = RTRIM( ISNULL( MAX( ORDET.Notes ), '' ) )  
        , Notes2            = RTRIM( ISNULL( MAX( ORDET.Notes2 ), '' ) )  
        , Route             = RTRIM( ISNULL( MAX( OH.Route ), '' ) )  
        , PickZone          = RTRIM( ISNULL( ORDET.PickZone, '' ) )  
        , Qty               = SUM( ORDET.Qty )  
    , ShoeGroup         = ORDET.ShoeGroup  
        , LabelCount        = CEILING(CASE WHEN EXISTS(select top 1 1  
                                      from dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes2)) b  
                                      where a.SeqNo=b.SeqNo and a.ColValue=ORDET.ShoeGroup and b.ColValue='Y')  
                                   THEN CONVERT(FLOAT, SUM(ORDET.Qty) ) / 5  
                                   WHEN MAX(ORDET.CartonCBM)>0 THEN SUM(ORDET.Qty * ORDET.stdcube) / MAX(ORDET.CartonCBM)  
                                   ELSE 1  
                              END)  
        , ZoneCount         = MAX( ISNULL( ZC.ZoneCount, 0 ) )  
        , ConsolPick        = RTRIM( ISNULL( MAX( ORDET.ConsolPick ), '' ) )  
        , CustPOType        = RTRIM( ISNULL( MAX( OH.Userdefine05 ), '' ) )  
  
   INTO #TEMP_ORDET2  
  
   FROM #TEMP_ORDET ORDET  
   JOIN dbo.ORDERS     OH (NOLOCK) ON (ORDET.FirstOrderKey = OH.Orderkey)  
   LEFT OUTER JOIN #TEMP_ZONECOUNT ZC ON ORDET.DocKey = ZC.DocKey  
  
   LEFT JOIN (  
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))  
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)  
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPCODE' AND Long=@c_DataWidnow AND Short='Y' AND UDF02='ShoeCode'  
   ) RptCfg2  
   ON RptCfg2.Storerkey=ORDET.Storerkey AND RptCfg2.SeqNo=1  
  
   GROUP BY ORDET.Storerkey  
          , ORDET.DocKey  
          , ISNULL( ORDET.PickZone, '' )  
          , ORDET.ShoeGroup  
  
  
   ------------------------  
   SELECT X.Storerkey, X.DocKey, X.DocNumber, X.PickSlipNo, X.Orderkey, X.Externorderkey, X.Wavekey, X.Loadkey, X.Deliverydate  
        , X.ConsigneeKey, X.C_Company, X.C_Address1, X.C_Address2, X.C_Address3, X.C_Address4, X.Notes, X.Notes2, X.Route  
        , X.PickZone, X.Qty, X.LabelCount, X.ZoneCount, X.ConsolPick  
        , SeqNo             = SeqTbl.Rowref  
        , DropID            = ISNULL(RTRIM(@c_DropIDPrefix),'ID') + ISNULL( RTRIM( X.DocKey ), '' ) + ISNULL( RTRIM( X.PickZone ), '') + FORMAT(SeqTbl.Rowref, '0000')  
        , ShowFields        = RptCfg.ShowFields  
        , datawindow        = @c_DataWidnow  
        , Lbl_DocNumber     = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes) a, dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes2) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DocNumber') ) AS NVARCHAR(500))  
        , CustPOType        = X.CustPOType  
   FROM (  
      SELECT Storerkey         = Storerkey  
           , DocKey            = DocKey  
           , DocNumber         = MAX( DocNumber )  
           , PickSlipNo        = MAX( PickSlipNo )  
           , Orderkey          = MAX( Orderkey )  
           , Externorderkey    = MAX( Externorderkey )  
           , Wavekey           = MAX( Wavekey )  
           , Loadkey           = MAX( Loadkey )  
           , Deliverydate      = MAX( Deliverydate )  
           , ConsigneeKey      = MAX( ConsigneeKey )  
           , C_Company         = MAX( C_Company )  
           , C_Address1        = MAX( C_Address1 )  
           , C_Address2        = MAX( C_Address2 )  
           , C_Address3        = MAX( C_Address3 )  
           , C_Address4        = MAX( C_Address4 )  
           , Notes             = MAX( Notes )  
           , Notes2            = MAX( Notes2 )  
           , Route             = MAX( Route )  
           , PickZone          = PickZone  
           , Qty               = SUM( Qty )  
           , LabelCount        = SUM( LabelCount )  
           , ZoneCount         = MAX( ZoneCount )  
           , ConsolPick        = MAX( ConsolPick )  
           , CustPOType        = MAX( CustPOType )  
           FROM #TEMP_ORDET2  
          GROUP BY Storerkey  
                 , DocKey  
                 , PickZone  
   ) X  
  
   LEFT JOIN (  
  SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))  
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)  
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWidnow AND Short='Y'  
   ) RptCfg  
   ON RptCfg.Storerkey=X.Storerkey AND RptCfg.SeqNo=1  
  
   LEFT JOIN (  
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))  
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)  
        FROM CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWidnow AND Short='Y'  
   ) RptCfg3  
   ON RptCfg3.Storerkey=X.Storerkey AND RptCfg3.SeqNo=1  
  
   JOIN dbo.SEQKey SeqTbl(NOLOCK) ON  
        SeqTbl.Rowref >= CASE WHEN @n_CartonNoFrom>0 AND @n_CartonNoTo>0 THEN @n_CartonNoFrom ELSE 1 END  
    AND SeqTbl.Rowref <= CASE WHEN @n_CartonNoFrom>0 AND @n_CartonNoTo>0 THEN @n_CartonNoTo ELSE X.LabelCount END  
  
   ORDER BY Storerkey, DocKey, PickZone  
  
END  

GO