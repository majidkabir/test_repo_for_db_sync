SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PackListBySku33_rdt                            */
/* Creation Date: 27-Apr-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22374 - AU_Levis_PackingList                            */
/*                                                                      */
/* Called By: report dw = r_dw_packing_list_by_sku33_rdt                */
/*                                                                      */
/* GitLab Version: 1.3                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver.  Purposes                                 */
/* 27-Apr-2023  WLChooi  1.0   DevOps Combine Script                    */
/* 03-Aug-2023  WLChooi  1.1   WMS-23219 - Logic change (WL01)          */
/* 05-Oct-2023  WLChooi  1.2   WMS-23219 - Address change (WL02)        */
/* 13-Oct-2023  JiHHaur  1.3   JSM-183445 - Add MAX(AddDate) (JH01)     */
/************************************************************************/

CREATE   PROC [dbo].[isp_PackListBySku33_rdt]
(@c_Pickslipno NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @n_Continue INT          = 1
         , @c_LabelNo  NVARCHAR(20) = N''
         , @n_TTLCTN   INT
         , @n_Weight   NUMERIC(20, 3)
         , @c_Adddate  NVARCHAR(10)
         , @c_Country_TXT  NVARCHAR(100) = N'Australia: '
         , @c_Phone_TXT    NVARCHAR(100) = N'(PH) 1800 888 505 '
         , @c_Fax_TXT      NVARCHAR(100) = N''
         , @c_FOOTER1_TXT  NVARCHAR(500) = N'LEVI STRAUSS (AUSTRALIA) PTY. LTD. ABN 67 000 607 965'
         , @c_FOOTER2_TXT  NVARCHAR(500) = N'Level 7, 11 Eastern Rd. SOUTH MELBOURNE, Victoria 3205      Telephone: 61 03 9864 0501'
         , @c_Email_TXT    NVARCHAR(500) = N'customerservice.lsanz@levi.com'
         , @c_Remark_TXT   NVARCHAR(500) = N'* Replenishment unshipped units require to be reordered '
         , @c_Orderkey     NVARCHAR(10) = N''
         , @c_Type         NVARCHAR(10) = N''
         , @c_BillToKey    NVARCHAR(50) = N''
         , @c_Storerkey    NVARCHAR(15) = N''
         , @c_AddrType     NVARCHAR(10) = N'C'
         , @c_Country      NVARCHAR(100) = N''

   --WL01 S
   DECLARE @c_SQLExec         NVARCHAR(MAX) = ''
         , @c_ExecArguments   NVARCHAR(MAX) = ''
         , @c_SQL             NVARCHAR(MAX) = ''
         , @c_B_State_Repl    NVARCHAR(4000) = ''
         , @c_B_Country_Repl  NVARCHAR(4000) = ''
         , @c_C_Country_Repl  NVARCHAR(4000) = ''
         , @c_CustomAddr      NVARCHAR(1) = 'N'
         , @c_B_Addr_L1       NVARCHAR(4000) = ''
         , @c_B_Addr_L2       NVARCHAR(4000) = ''
         , @c_B_Addr_L3       NVARCHAR(4000) = ''
         , @c_B_Addr_L4       NVARCHAR(4000) = ''
         , @c_B_Addr_L5       NVARCHAR(4000) = ''
         , @c_S_Addr_L1       NVARCHAR(4000) = ''
         , @c_S_Addr_L2       NVARCHAR(4000) = ''
         , @c_S_Addr_L3       NVARCHAR(4000) = ''
         , @c_S_Addr_L4       NVARCHAR(4000) = ''
         , @c_S_Addr_L5       NVARCHAR(4000) = ''
   --WL01 E

   SELECT @c_Orderkey  = ORDERS.Orderkey
        , @c_Type      = ORDERS.[Type]
        , @c_BillToKey = ORDERS.BillToKey
        , @c_Storerkey = ORDERS.StorerKey
        , @c_Country   = ORDERS.C_Country
   FROM PACKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = PACKHEADER.OrderKey
   WHERE Pickslipno = @c_Pickslipno

   ----WL01 S
   --IF @c_Type <> 'B2C'
   --BEGIN
   --   IF NOT EXISTS ( SELECT TOP 1 1
   --                   FROM CODELKUP (NOLOCK) 
   --                   WHERE LISTNAME = 'LVPLSTBADD' AND Storerkey = @c_Storerkey 
   --                   AND Code = @c_BillToKey )
   --   BEGIN
   --      SET @c_AddrType = 'C'
   --   END
   --   ELSE
   --   BEGIN
   --      SET @c_AddrType = 'B'
   --   END
   --END
   --ELSE
   --BEGIN
   --   SET @c_AddrType = 'C'
   --END

   CREATE TABLE #T_ADDR (
        Addr_L1  NVARCHAR(500) NULL
      , Addr_L2  NVARCHAR(500) NULL
      , Addr_L3  NVARCHAR(500) NULL
      , Addr_L4  NVARCHAR(500) NULL
      , Addr_L5  NVARCHAR(500) NULL
      , AddrType NVARCHAR(10)  NULL)

   IF @c_Type <> 'B2C'
   BEGIN
      --Bill To Addr - START
      SELECT @c_SQL = STUFF((SELECT TOP 5 ',' + TRIM(Long) FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'LVSPLB2BB' ORDER BY CAST(Code AS INT) FOR XML PATH('')),1,1,'' )

      SELECT @c_SQL = REPLACE(@c_SQL,'B_ISOCntryCode','IIF(ISNULL(CL.Code,'''') = '''', ISNULL(ORDERS.B_ISOCntryCode,''''), ISNULL(CL.Long,'''')) ')

      SELECT @c_SQL = ' INSERT INTO #T_ADDR SELECT ' + @c_SQL + ', ''B'' ' + CHAR(13)
                    + ' FROM ORDERS (NOLOCK) ' + CHAR(13)
                    + ' LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = ''LVSPLCC'' AND CL.Storerkey = ORDERS.Storerkey ' + CHAR(13)
                    + '                               AND CL.Code = ORDERS.B_ISOCntryCode ' + CHAR(13)
                    + ' WHERE Orderkey = @c_Orderkey '

      SELECT @c_B_State_Repl = 'CASE WHEN ISNULL(B_State, '''') = '''' 
                                     THEN CASE WHEN B_Country = ''AU'' OR B_ISOCntryCode = ''AU'' THEN CASE WHEN B_Zip LIKE ''3%'' THEN ''VIC''
                                                                                                            WHEN B_Zip LIKE ''4%'' THEN ''QLD''
                                                                                                            WHEN B_Zip LIKE ''5%'' THEN ''SA''
                                                                                                            WHEN B_Zip LIKE ''0%'' THEN ''NT''
                                                                                                            WHEN B_Zip LIKE ''6%'' THEN ''WA''
                                                                                                            WHEN B_Zip LIKE ''7%'' THEN ''TAS''
                                                                                                            WHEN ((B_Zip >= ''2600'' AND B_Zip <= ''2618'') 
                                                                                                               OR (B_Zip >= ''2900'' AND B_Zip <= ''2920'')) THEN ''ACT''
                                                                                                            ELSE ''NSW'' 
                                                                                                            END
                                               WHEN B_Country = ''NZ'' OR B_ISOCntryCode = ''NZ'' THEN CASE WHEN LEFT(TRIM(ISNULL(B_Zip,'''')),1) IN (''7'',''8'',''9'') THEN ''SI''
                                                                                                            ELSE ''NI''
                                                                                                            END
                                          END
                                     ELSE ISNULL(B_State, '''') END '

      SELECT @c_SQL = REPLACE(@c_SQL,'B_STATE',@c_B_State_Repl)

      SET @c_B_Country_Repl = 'CASE WHEN ISNULL(B_Country, '''') = '''' THEN ISNULL(B_ISOCntryCode, '''') ELSE ISNULL(B_Country, '''') END '

      SELECT @c_SQL = REPLACE(@c_SQL,'B_Country',@c_B_Country_Repl)

      SELECT @c_C_Country_Repl = 'CASE C_Country WHEN ''AU'' THEN ''Australia'' 
                                                 WHEN ''NZ'' THEN ''New Zealand'' 
                                                 WHEN ''HK'' THEN ''Hong Kong'' 
                                                 WHEN ''KR'' THEN ''South Korea'' ELSE C_Country END'
      
      SELECT @c_SQL = REPLACE(@c_SQL,'C_Country',@c_C_Country_Repl)

      SET @c_ExecArguments = N'  @c_Orderkey         NVARCHAR(10)'     

      EXEC sp_executesql @c_SQL    
                       , @c_ExecArguments    
                       , @c_Orderkey    
      --Bill To Addr - END

      --Ship To Addr - START
      SELECT @c_SQL = STUFF((SELECT TOP 5 ',' + TRIM(Long) FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'LVSPLB2BS' ORDER BY CAST(Code AS INT) FOR XML PATH('')),1,1,'' )
      SELECT @c_SQL = ' INSERT INTO #T_ADDR SELECT ' + @c_SQL + ', ''S'' FROM ORDERS (NOLOCK) WHERE Orderkey = @c_Orderkey '
      
      SELECT @c_B_State_Repl = 'CASE WHEN ISNULL(B_State, '''') = '''' 
                                     THEN CASE WHEN B_Country = ''AU'' OR B_ISOCntryCode = ''AU'' THEN CASE WHEN B_Zip LIKE ''3%'' THEN ''VIC''
                                                                                                            WHEN B_Zip LIKE ''4%'' THEN ''QLD''
                                                                                                            WHEN B_Zip LIKE ''5%'' THEN ''SA''
                                                                                                            WHEN B_Zip LIKE ''0%'' THEN ''NT''
                                                                                                            WHEN B_Zip LIKE ''6%'' THEN ''WA''
                                                                                                            WHEN B_Zip LIKE ''7%'' THEN ''TAS''
                                                                                                            WHEN ((B_Zip >= ''2600'' AND B_Zip <= ''2618'') 
                                                                                                               OR (B_Zip >= ''2900'' AND B_Zip <= ''2920'')) THEN ''ACT''
                                                                                                            ELSE ''NSW'' 
                                                                                                            END
                                               WHEN B_Country = ''NZ'' OR B_ISOCntryCode = ''NZ'' THEN CASE WHEN LEFT(TRIM(ISNULL(B_Zip,'''')),1) IN (''7'',''8'',''9'') THEN ''SI''
                                                                                                            ELSE ''NI''
                                                                                                            END
                                          END
                                     ELSE ISNULL(B_State, '''') END '

      SELECT @c_SQL = REPLACE(@c_SQL,'B_STATE',@c_B_State_Repl)

      SET @c_B_Country_Repl = 'CASE WHEN ISNULL(B_Country, '''') = '''' THEN ISNULL(B_ISOCntryCode, '''') ELSE ISNULL(B_Country, '''') END '

      SELECT @c_SQL = REPLACE(@c_SQL,'B_Country',@c_B_Country_Repl)

      SELECT @c_C_Country_Repl = 'CASE C_Country WHEN ''AU'' THEN ''Australia'' 
                                                 WHEN ''NZ'' THEN ''New Zealand'' 
                                                 WHEN ''HK'' THEN ''Hong Kong'' 
                                                 WHEN ''KR'' THEN ''South Korea'' ELSE C_Country END'
      
      SELECT @c_SQL = REPLACE(@c_SQL,'C_Country',@c_C_Country_Repl)

      SET @c_ExecArguments = N'  @c_Orderkey         NVARCHAR(10)'     
       
      EXEC sp_executesql @c_SQL    
                       , @c_ExecArguments    
                       , @c_Orderkey    
      --Ship To Addr - END
   END
   ELSE
   BEGIN
      --Bill To Addr - START
      SELECT @c_SQL = STUFF((SELECT TOP 5 ',' + TRIM(Long) FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'LVSPLB2BS' ORDER BY CAST(Code AS INT) FOR XML PATH('')),1,1,'' )

      SELECT @c_SQL = REPLACE(@c_SQL,'B_ISOCntryCode','IIF(ISNULL(CL.Code,'''') = '''', ISNULL(ORDERS.B_ISOCntryCode,''''), ISNULL(CL.Long,'''')) ')

      SELECT @c_SQL = ' INSERT INTO #T_ADDR SELECT ' + @c_SQL + ', ''B'' ' + CHAR(13)
                    + ' FROM ORDERS (NOLOCK) ' + CHAR(13)
                    + ' LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = ''LVSPLCC'' AND CL.Storerkey = ORDERS.Storerkey ' + CHAR(13)
                    + '                               AND CL.Code = ORDERS.B_ISOCntryCode ' + CHAR(13)
                    + ' WHERE Orderkey = @c_Orderkey '

      SET @c_B_Country_Repl = 'CASE WHEN ISNULL(B_Country, '''') = '''' THEN ISNULL(B_ISOCntryCode, '''') ELSE ISNULL(B_Country, '''') END '

      SELECT @c_SQL = REPLACE(@c_SQL,'B_Country',@c_B_Country_Repl)

      SELECT @c_C_Country_Repl = 'CASE C_Country WHEN ''AU'' THEN ''Australia'' 
                                                 WHEN ''NZ'' THEN ''New Zealand'' 
                                                 WHEN ''HK'' THEN ''Hong Kong'' 
                                                 WHEN ''KR'' THEN ''South Korea'' ELSE C_Country END'
      
      SELECT @c_SQL = REPLACE(@c_SQL,'C_Country',@c_C_Country_Repl)

      SET @c_ExecArguments = N'  @c_Orderkey         NVARCHAR(10)'     
       
      EXEC sp_executesql @c_SQL    
                       , @c_ExecArguments    
                       , @c_Orderkey    
      --Bill To Addr - END

      --Ship To Addr - START
      SELECT @c_SQL = STUFF((SELECT TOP 5 ',' + TRIM(Long) FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'LVSPLB2C' ORDER BY CAST(Code AS INT) FOR XML PATH('')),1,1,'' )
      SELECT @c_SQL = ' INSERT INTO #T_ADDR SELECT ' + @c_SQL + ', ''S'' FROM ORDERS (NOLOCK) WHERE Orderkey = @c_Orderkey '

      SET @c_B_Country_Repl = 'CASE WHEN ISNULL(B_Country, '''') = '''' THEN ISNULL(B_ISOCntryCode, '''') ELSE ISNULL(B_Country, '''') END '

      SELECT @c_SQL = REPLACE(@c_SQL,'B_Country',@c_B_Country_Repl)

      SELECT @c_C_Country_Repl = 'CASE C_Country WHEN ''AU'' THEN ''Australia'' 
                                                 WHEN ''NZ'' THEN ''New Zealand'' 
                                                 WHEN ''HK'' THEN ''Hong Kong'' 
                                                 WHEN ''KR'' THEN ''South Korea'' ELSE C_Country END'
      
      SELECT @c_SQL = REPLACE(@c_SQL,'C_Country',@c_C_Country_Repl)

      SET @c_ExecArguments = N'  @c_Orderkey         NVARCHAR(10)'     
       
      EXEC sp_executesql @c_SQL    
                       , @c_ExecArguments    
                       , @c_Orderkey 
      --Ship To Addr - END
   END

   SELECT @c_B_Addr_L1 = T.Addr_L1
        , @c_B_Addr_L2 = T.Addr_L2
        , @c_B_Addr_L3 = T.Addr_L3
        , @c_B_Addr_L4 = T.Addr_L4
        , @c_B_Addr_L5 = T.Addr_L5
   FROM #T_ADDR T
   WHERE T.AddrType = 'B'

   SELECT @c_S_Addr_L1 = T.Addr_L1
        , @c_S_Addr_L2 = T.Addr_L2
        , @c_S_Addr_L3 = T.Addr_L3
        , @c_S_Addr_L4 = T.Addr_L4
        , @c_S_Addr_L5 = T.Addr_L5
   FROM #T_ADDR T
   WHERE T.AddrType = 'S'
   --WL01 E

   CREATE TABLE #T_ORD
   (
      C_Address1      NVARCHAR(100) NULL
    , C_City          NVARCHAR(100) NULL
    , C_State         NVARCHAR(100) NULL
    , C_Zip           NVARCHAR(100) NULL
    , C_Country       NVARCHAR(100) NULL
    , ExternOrderKey  NVARCHAR(50)  NULL
    , EffectiveDate   NVARCHAR(50)  NULL
    , ConsigneeKey    NVARCHAR(15)  NULL
    , BuyerPO         NVARCHAR(50)  NULL
    , ORDAddDate      NVARCHAR(10)  NULL
    , C_Company       NVARCHAR(100) NULL
    , SKU             NVARCHAR(20)  NULL
    , DESCR           NVARCHAR(200) NULL
    , Size            NVARCHAR(20)  NULL
    , Style           NVARCHAR(20)  NULL
    , MANUFACTURERSKU NVARCHAR(20)  NULL
    , OriginalQty     INT           NULL
    , Storerkey       NVARCHAR(15)  NULL
    , C_Contact1      NVARCHAR(100) NULL
    , C_Address4      NVARCHAR(100) NULL
    , B_Company       NVARCHAR(100) NULL
    , B_Address1      NVARCHAR(100) NULL
    , B_City          NVARCHAR(100) NULL
    , B_State         NVARCHAR(100) NULL
    , B_Zip           NVARCHAR(100) NULL
    , B_Country       NVARCHAR(100) NULL
    , B_Contact1      NVARCHAR(100) NULL
    , B_Address2      NVARCHAR(100) NULL
    , [Type]          NVARCHAR(30)  NULL
   )

   CREATE TABLE #T_PD
   (
      LabelNo   NVARCHAR(20)   NULL
    , SKU       NVARCHAR(20)   NULL
    , PDQty     INT            NULL
    , TTLCTN    INT            NULL
    , [Weight]  NUMERIC(20, 3) NULL
    , Storerkey NVARCHAR(15)   NULL
    , Adddate   NVARCHAR(10)   NULL
   )

   CREATE TABLE #T_RESULT
   (
      C_Address1      NVARCHAR(100)  NULL
    , C_City          NVARCHAR(100)  NULL
    , C_State         NVARCHAR(100)  NULL
    , C_Zip           NVARCHAR(100)  NULL
    , C_Country       NVARCHAR(100)  NULL
    , ExternOrderKey  NVARCHAR(50)   NULL
    , EffectiveDate   NVARCHAR(50)   NULL
    , ConsigneeKey    NVARCHAR(15)   NULL
    , BuyerPO         NVARCHAR(50)   NULL
    , ORDAddDate      NVARCHAR(10)   NULL
    , C_Company       NVARCHAR(100)  NULL
    , SKU             NVARCHAR(20)   NULL
    , DESCR           NVARCHAR(200)  NULL
    , Size            NVARCHAR(20)   NULL
    , Style           NVARCHAR(20)   NULL
    , MANUFACTURERSKU NVARCHAR(20)   NULL
    , OriginalQty     INT            NULL
    , Storerkey       NVARCHAR(15)   NULL
    , LabelNo         NVARCHAR(20)   NULL
    , PDQty           INT            NULL
    , TTLCTN          INT            NULL
    , [Weight]        NUMERIC(20, 3) NULL
    , Adddate         NVARCHAR(10)   NULL
    , UnshippedQty    INT            NULL
    , C_Contact1      NVARCHAR(100)  NULL
    , C_Address4      NVARCHAR(100)  NULL
    , B_Company       NVARCHAR(100)  NULL
    , B_Address1      NVARCHAR(100)  NULL
    , B_City          NVARCHAR(100)  NULL
    , B_State         NVARCHAR(100)  NULL
    , B_Zip           NVARCHAR(100)  NULL
    , B_Country       NVARCHAR(100)  NULL
    , B_Contact1      NVARCHAR(100)  NULL
    , B_Address2      NVARCHAR(100)  NULL
    , [Type]          NVARCHAR(30)   NULL
   )

   INSERT INTO #T_ORD (C_Address1, C_City, C_State, C_Zip, C_Country, ExternOrderKey, EffectiveDate, ConsigneeKey
                     , BuyerPO, ORDAddDate, C_Company, SKU, DESCR, Size, Style, MANUFACTURERSKU, OriginalQty, Storerkey
                     , C_Contact1, C_Address4
                     , B_Company, B_Address1, B_City, B_State, B_Zip, B_Country, B_Contact1, B_Address2, [Type])
   SELECT ''--ISNULL(OH.C_Address1, '')   --WL01 S
        , ''--ISNULL(OH.C_City, '')
        , ''--ISNULL(OH.C_State, '')
        , ''--ISNULL(OH.C_Zip, '')
        , ''--ISNULL(OH.C_Country, '')   --WL01 E
        , ISNULL(TRIM(OH.ExternOrderKey), '')
        , CONVERT(NVARCHAR(10), ISNULL(OH.EffectiveDate, '19000101'), 104)
        , ISNULL(OH.ConsigneeKey, '')
        , ISNULL(OH.BuyerPO, '')
        , CONVERT(NVARCHAR(10), OH.AddDate, 104)
        , ''--ISNULL(OH.C_Company, '')   --WL01
        , TRIM(S.Sku)
        , ISNULL(S.DESCR, '')
        , ISNULL(S.Size, '')
        , ISNULL(S.Style, '')
        , ISNULL(S.MANUFACTURERSKU, '')
        , SUM(OD.OriginalQty) AS OriginalQty
        , OH.StorerKey
        , ''--ISNULL(OH.C_Contact1, '')   --WL01 S
        , ''--ISNULL(OH.C_Address4, '')
        , ''--CASE WHEN @c_AddrType = 'B' THEN ISNULL(OH.B_Company, '') ELSE ISNULL(OH.C_Company, '') END
        , ''--CASE WHEN @c_AddrType = 'B' THEN ISNULL(OH.B_Address1, '') ELSE ISNULL(OH.C_Address1, '') END
        , ''--CASE WHEN @c_AddrType = 'B' THEN ISNULL(OH.B_City, '') ELSE ISNULL(OH.C_City, '') END
        , ''--CASE WHEN @c_AddrType = 'B' THEN CASE WHEN ISNULL(OH.B_State, '') = '' 
          --                                      THEN CASE WHEN OH.B_Country = 'AU' OR OH.B_ISOCntryCode = 'AU' THEN CASE WHEN OH.B_Zip LIKE '3%' THEN 'VIC'
          --                                                                                                               WHEN OH.B_Zip LIKE '4%' THEN 'QLD'
          --                                                                                                               WHEN OH.B_Zip LIKE '5%' THEN 'SA'
          --                                                                                                               WHEN OH.B_Zip LIKE '0%' THEN 'NT'
          --                                                                                                               WHEN OH.B_Zip LIKE '6%' THEN 'WA'
          --                                                                                                               WHEN OH.B_Zip LIKE '7%' THEN 'TAS'
          --                                                                                                               WHEN ((OH.B_Zip >= '2600' AND OH.B_Zip <= '2618') 
          --                                                                                                                  OR (OH.B_Zip >= '2900' AND OH.B_Zip <= '2920')) THEN 'ACT'
          --                                                                                                               ELSE 'NSW' 
          --                                                                                                               END
          --                                                WHEN OH.B_Country = 'NZ' OR OH.B_ISOCntryCode = 'NZ' THEN CASE WHEN LEFT(TRIM(ISNULL(OH.B_Zip,'')),1) IN ('7','8','9') THEN 'SI'
          --                                                                                                               ELSE 'NI'
          --                                                                                                               END
          --                                           END
          --                                      ELSE ISNULL(OH.B_State, '') END ELSE ISNULL(OH.C_State, '') END
        , ''--CASE WHEN @c_AddrType = 'B' THEN ISNULL(OH.B_Zip, '') ELSE ISNULL(OH.C_Zip, '') END
        , ''--CASE WHEN @c_AddrType = 'B' THEN CASE WHEN ISNULL(OH.B_Country, '') = '' 
          --                                      THEN ISNULL(OH.B_ISOCntryCode, '') 
          --                                      ELSE ISNULL(OH.B_Country, '') END ELSE ISNULL(OH.C_Country, '') END
        , ''--CASE WHEN @c_AddrType = 'B' THEN ISNULL(OH.B_Contact1, '') ELSE ISNULL(OH.C_Contact1, '') END
        , ''--CASE WHEN @c_AddrType = 'B' THEN ISNULL(OH.B_Address2, '') ELSE ISNULL(OH.C_Address4, '') END   --WL01 E
        , OH.[Type]
   FROM PackHeader PH (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.Sku = OD.Sku
   WHERE PH.PickSlipNo = @c_Pickslipno
   --GROUP BY CASE WHEN @c_AddrType = 'B' THEN ISNULL(OH.B_Address1, '') ELSE ISNULL(OH.C_Address1, '') END   --WL01 S
   --       , CASE WHEN @c_AddrType = 'B' THEN ISNULL(OH.B_City, '') ELSE ISNULL(OH.C_City, '') END
   --       , CASE WHEN @c_AddrType = 'B' THEN CASE WHEN ISNULL(OH.B_State, '') = '' 
   --                                               THEN CASE WHEN OH.B_Country = 'AU' OR OH.B_ISOCntryCode = 'AU' THEN CASE WHEN OH.B_Zip LIKE '3%' THEN 'VIC'
   --                                                                                                                        WHEN OH.B_Zip LIKE '4%' THEN 'QLD'
   --                                                                                                                        WHEN OH.B_Zip LIKE '5%' THEN 'SA'
   --                                                                                                                        WHEN OH.B_Zip LIKE '0%' THEN 'NT'
   --                                                                                                                        WHEN OH.B_Zip LIKE '6%' THEN 'WA'
   --                                                                                                                        WHEN OH.B_Zip LIKE '7%' THEN 'TAS'
   --                                                                                                                        WHEN ((OH.B_Zip >= '2600' AND OH.B_Zip <= '2618') 
   --                                                                                                                           OR (OH.B_Zip >= '2900' AND OH.B_Zip <= '2920')) THEN 'ACT'
   --                                                                                                                        ELSE 'NSW' 
   --                                                                                                                        END
   --                                                         WHEN OH.B_Country = 'NZ' OR OH.B_ISOCntryCode = 'NZ' THEN CASE WHEN LEFT(TRIM(ISNULL(OH.B_Zip,'')),1) IN ('7','8','9') THEN 'SI'
   --                                                                                                                        ELSE 'NI'
   --                                                                                                                        END
   --                                                    END
   --                                               ELSE ISNULL(OH.B_State, '') END ELSE ISNULL(OH.C_State, '') END
   --       , CASE WHEN @c_AddrType = 'B' THEN ISNULL(OH.B_Zip, '') ELSE ISNULL(OH.C_Zip, '') END
   --       , CASE WHEN @c_AddrType = 'B' THEN CASE WHEN ISNULL(OH.B_Country, '') = '' 
   --                                               THEN ISNULL(OH.B_ISOCntryCode, '') 
   --                                               ELSE ISNULL(OH.B_Country, '') END ELSE ISNULL(OH.C_Country, '') END   --WL01 E
   GROUP BY ISNULL(TRIM(OH.ExternOrderKey), '')
          , CONVERT(NVARCHAR(10), ISNULL(OH.EffectiveDate, '19000101'), 104)
          , ISNULL(OH.ConsigneeKey, '')
          , ISNULL(OH.BuyerPO, '')
          , CONVERT(NVARCHAR(10), OH.AddDate, 104)
          --, CASE WHEN @c_AddrType = 'B' THEN ISNULL(OH.B_Company, '') ELSE ISNULL(OH.C_Company, '') END   --WL01
          , TRIM(S.Sku)
          , ISNULL(S.DESCR, '')
          , ISNULL(S.Size, '')
          , ISNULL(S.Style, '')
          , ISNULL(S.MANUFACTURERSKU, '')
          , OH.StorerKey
          --, CASE WHEN @c_AddrType = 'B' THEN ISNULL(OH.B_Contact1, '') ELSE ISNULL(OH.C_Contact1, '') END   --WL01 S
          --, CASE WHEN @c_AddrType = 'B' THEN ISNULL(OH.B_Address2, '') ELSE ISNULL(OH.C_Address4, '') END
          --, ISNULL(OH.C_Address1, '')
          --, ISNULL(OH.C_City, '')
          --, ISNULL(OH.C_State, '')
          --, ISNULL(OH.C_Zip, '')
          --, ISNULL(OH.C_Country, '')
          --, ISNULL(OH.C_Company, '')
          --, ISNULL(OH.C_Contact1, '')
          --, ISNULL(OH.C_Address4, '')   --WL01 E
          , OH.[Type]

   --NZ PACKING LIST
   IF EXISTS (  SELECT 1
                FROM #T_ORD TOR (NOLOCK)
                JOIN CODELKUP CL (NOLOCK) ON  CL.LISTNAME = 'PCKLISTNZ'
                                          AND CL.Storerkey = TOR.Storerkey
                                          AND CL.Code = @C_Country   --WL01
                                          AND CL.UDF01 <> TOR.[Type] )
   BEGIN
      SET @c_Country_TXT = N'New Zealand: '
      SET @c_Phone_TXT = N'(PH) 0508 501 555 '
      SET @c_FOOTER1_TXT = N'LEVI STRAUSS (NEW ZEALAND) LTD GST Reg No 13 920 346 '
      SET @c_FOOTER2_TXT = N'PO Box 37 379, Parnell, Auckland, 1151      Telephone: 64 9 309 0319'
   END

   IF EXISTS (  SELECT 1
                FROM CODELKUP CL (NOLOCK) WHERE CL.LISTNAME = 'PCKLSTB2C'
                                            AND CL.Storerkey = @c_Storerkey
                                            AND CL.Short = @c_BillToKey
                                            AND CL.Code = 'EAU' )
   BEGIN
      UPDATE #T_ORD
      SET B_Company  = 'LEVI''S AUSTRALIA ONLINE '
        , B_Contact1 = ''
        , B_Address1 = 'LEVI STRAUSS AUST PTY LTD '
        , B_Address2 = '17 REID WAY '   --WL02
        , B_City     = 'MELBOURNE AIRPORT'   --WL02
        , B_State    = 'VICTORIA'   --WL02
        , B_Zip      = '3045'   --WL02
        , B_Country  = 'AUSTRALIA'
        , C_Company  = '17 REID WAY'   --WL02
        , C_Contact1 = ''
        , C_Address1 = ''
        , C_Address4 = ''
        , C_City     = 'MELBOURNE AIRPORT'   --WL02
        , C_State    = 'VICTORIA'   --WL02
        , C_Zip      = '3045'   --WL02
        , C_Country  = 'AUSTRALIA'
      WHERE Storerkey = @c_Storerkey

      SET @c_Country_TXT = N'AUSTRALIA: '
      SET @c_Phone_TXT = N'(PH) 1800 625 603 '
      SET @c_Email_TXT = N'CUSTOMERCARE@LEVIS.COM.AU'
      SET @c_Remark_TXT = N''
      SET @c_FOOTER2_TXT = N'Level 7, 11 Eastern Rd. SOUTH MELBOURNE, Victoria 3205      Telephone: 61 03 9864 0501 '
      SET @c_CustomAddr = 'Y'   --WL01
   END

   IF EXISTS (  SELECT 1
                FROM CODELKUP CL (NOLOCK) WHERE CL.LISTNAME = 'PCKLSTB2C'
                                            AND CL.Storerkey = @c_Storerkey
                                            AND CL.Short = @c_BillToKey
                                            AND CL.Code = 'I' )
   BEGIN
      UPDATE #T_ORD
      SET B_Company  = 'THE ICONIC DROPSHIP '
        , B_Contact1 = ''
        , B_Address1 = 'INTERNET SERVICES AUSTRALIA 1 P/L '
        , B_Address2 = 'LEVEL 18, 338 PITT STREET '
        , B_City     = 'SYDNEY'
        , B_State    = 'NEW SOUTH WALES'
        , B_Zip      = '2000'
        , B_Country  = 'AUSTRALIA'
        , C_Company  = 'INTERNET SERVICES AUSTRALIA 1 P/L '
        , C_Contact1 = ''
        , C_Address1 = 'LEVEL 18, 338 PITT STREET '
        , C_Address4 = ''
        , C_City     = 'SYDNEY'
        , C_State    = 'NEW SOUTH WALES'
        , C_Zip      = '2000'
        , C_Country  = 'AUSTRALIA'
      WHERE Storerkey = @c_Storerkey

      SET @c_Remark_TXT = N''
      SET @c_FOOTER2_TXT = N'Level 7, 11 Eastern Rd. SOUTH MELBOURNE, Victoria 3205      Telephone: 61 03 9864 0501 '
      SET @c_CustomAddr = 'Y'   --WL01
   END

   IF EXISTS (  SELECT 1
                FROM CODELKUP CL (NOLOCK) WHERE CL.LISTNAME = 'PCKLSTB2C'
                                            AND CL.Storerkey = @c_Storerkey
                                            AND CL.Short = @c_BillToKey
                                            AND CL.Code = 'S' )
   BEGIN
      UPDATE #T_ORD
      SET B_Company  = 'SURFSTITCH PTY LTD - DROPSHIP '
        , B_Contact1 = ''
        , B_Address1 = 'SURFSTITCH DROPSHIP '
        , B_Address2 = 'LOCKED BAG 7 '
        , B_City     = 'GOLD COAST MC'
        , B_State    = 'QUEENSLAND'
        , B_Zip      = '9726'
        , B_Country  = 'AUSTRALIA'
        , C_Company  = 'SURFSTITCH DROPSHIP '
        , C_Contact1 = ''
        , C_Address1 = 'LOCKED BAG 7 '
        , C_Address4 = ''
        , C_City     = 'GOLD COAST MC'
        , C_State    = 'QUEENSLAND'
        , C_Zip      = '9726'
        , C_Country  = 'AUSTRALIA'
      WHERE Storerkey = @c_Storerkey

      SET @c_Remark_TXT = N''
      SET @c_FOOTER2_TXT = N'Level 7, 11 Eastern Rd. SOUTH MELBOURNE, Victoria 3205      Telephone: 61 03 9864 0501 '
      SET @c_CustomAddr = 'Y'   --WL01
   END

   IF EXISTS (  SELECT 1
                FROM CODELKUP CL (NOLOCK) WHERE CL.LISTNAME = 'PCKLSTB2C'
                                            AND CL.Storerkey = @c_Storerkey
                                            AND CL.Short = @c_BillToKey
                                            AND CL.Code = 'ENZ'
                                            AND CL.UDF01 = @c_Country)
   BEGIN
      UPDATE #T_ORD
      SET B_Company  = 'LEVI''S AUSTRALIA ONLINE '
        , B_Contact1 = ''
        , B_Address1 = 'LEVI STRAUSS AUST PTY LTD '
        , B_Address2 = '17 REID WAY '   --WL02
        , B_City     = 'MELBOURNE AIRPORT'   --WL02
        , B_State    = 'VICTORIA'   --WL02
        , B_Zip      = '3045'   --WL02
        , B_Country  = 'AUSTRALIA'
        , C_Company  = '17 REID WAY '   --WL02'
        , C_Contact1 = ''
        , C_Address1 = ''
        , C_Address4 = ''
        , C_City     = 'MELBOURNE AIRPORT'   --WL02
        , C_State    = 'VICTORIA'   --WL02
        , C_Zip      = '3045'   --WL02
        , C_Country  = 'AUSTRALIA'
      WHERE Storerkey = @c_Storerkey

      SET @c_Country_TXT = N'New Zealand: '
      SET @c_Phone_TXT = N'(PH) 0508 501 555 '
      SET @c_Email_TXT = N'NZCUSTOMERCARE@LEVIS.COM.AU'
      SET @c_Remark_TXT = N''
      SET @c_FOOTER2_TXT = N'Level 7, 11 Eastern Rd. SOUTH MELBOURNE, Victoria 3205      Telephone: 61 03 9864 0501 '
      SET @c_CustomAddr = 'Y'   --WL01
   END

   IF EXISTS (  SELECT 1
                FROM CODELKUP CL (NOLOCK) WHERE CL.LISTNAME = 'B2CB2K'
                                            AND CL.Storerkey = @c_Storerkey
                                            AND CL.Code = @c_Type )
   BEGIN
      UPDATE #T_ORD
      SET ConsigneeKey = @c_BillToKey
      WHERE Storerkey = @c_Storerkey
   END
   
   INSERT INTO #T_PD (LabelNo, SKU, PDQty, TTLCTN, [Weight], Storerkey, Adddate)
   SELECT ''--TRIM(PD.LabelNo)
        , TRIM(PD.SKU)
        , SUM(PD.Qty)
        , (  SELECT COUNT(DISTINCT PackDetail.CartonNo)
             FROM PackDetail (NOLOCK)
             WHERE PackDetail.PickSlipNo = PD.PickSlipNo)
        , CAST(PIF.[Weight] / 1000 AS NUMERIC(20, 3))
        , PD.StorerKey
        , MAX(CONVERT(NVARCHAR(10), PD.AddDate, 104))
   FROM PackDetail PD (NOLOCK)
   CROSS APPLY (  SELECT SUM(PackInfo.[Weight]) AS [Weight]
                  FROM PackInfo (NOLOCK)
                  WHERE PackInfo.PickSlipNo = PD.PickSlipNo) AS PIF
   WHERE PD.PickSlipNo = @c_Pickslipno
   GROUP BY TRIM(PD.SKU)
          , PIF.[Weight]
          , PD.PickSlipNo
          , PD.StorerKey

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TP.LabelNo
        , TP.TTLCTN
        , TP.[Weight]
        , MAX(TP.Adddate)     /*JH01*/
   FROM #T_PD TP
   GROUP BY TP.LabelNo
          , TP.TTLCTN
          , TP.[Weight]
          /*, TP.Adddate JH01*/
   ORDER BY TP.LabelNo

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP
   INTO @c_LabelNo
      , @n_TTLCTN
      , @n_Weight
      , @c_Adddate

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      INSERT INTO #T_RESULT (LabelNo, C_Address1, C_City, C_State, C_Zip, C_Country, ExternOrderKey, EffectiveDate
                           , ConsigneeKey, BuyerPO, ORDAddDate, Adddate, DESCR, SKU, Size, OriginalQty, PDQty, [Weight]
                           , TTLCTN, C_Company, Style, MANUFACTURERSKU, UnshippedQty, C_Contact1, C_Address4
                           , B_Company, B_Address1, B_City, B_State, B_Zip, B_Country, B_Contact1, B_Address2, [Type])
      SELECT @c_LabelNo
           , TOR.C_Address1
           , TRIM(TOR.C_City)
           , TRIM(TOR.C_State)
           , TRIM(TOR.C_Zip)
           , ''   --WL01
           , TOR.ExternOrderKey
           , TOR.EffectiveDate
           , TOR.ConsigneeKey
           , TOR.BuyerPO
           , TOR.ORDAddDate
           , @c_Adddate
           , TOR.DESCR
           , TOR.SKU
           , TOR.Size
           , TOR.OriginalQty
           , ISNULL((  SELECT SUM(TP.PDQty)
                       FROM #T_PD TP (NOLOCK)
                       WHERE TP.LabelNo = @c_LabelNo AND TP.SKU = TOR.SKU)
                  , 0)
           , @n_Weight
           , @n_TTLCTN
           , TOR.C_Company
           , TOR.Style
           , TOR.MANUFACTURERSKU
           , TOR.OriginalQty - ISNULL((  SELECT SUM(TP.PDQty)
                                         FROM #T_PD TP (NOLOCK)
                                         WHERE TP.SKU = TOR.SKU)
                                    , 0)
           , TRIM(TOR.C_Contact1)
           , TRIM(TOR.C_Address4)
           , TRIM(TOR.B_Company)
           , TRIM(TOR.B_Address1)
           , TRIM(TOR.B_City)
           , TRIM(TOR.B_State)
           , TRIM(TOR.B_Zip)
           , CASE TOR.B_Country WHEN 'AU' THEN 'Australia' 
                                WHEN 'NZ' THEN 'New Zealand' 
                                WHEN 'HK' THEN 'Hong Kong' 
                                WHEN 'KR' THEN 'South Korea' ELSE TOR.B_Country END
           , TRIM(TOR.B_Contact1)
           , TRIM(TOR.B_Address2)
           , TOR.[Type]
      FROM #T_ORD TOR (NOLOCK)
      ORDER BY TOR.SKU

      FETCH NEXT FROM CUR_LOOP
      INTO @c_LabelNo
         , @n_TTLCTN
         , @n_Weight
         , @c_Adddate
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   SELECT LabelNo
        , C_Addr_L1 = CASE WHEN @c_CustomAddr = 'Y' THEN C_Company + ' ' + C_Contact1 ELSE @c_S_Addr_L1 END   --WL01
        , C_Addr_L2 = CASE WHEN @c_CustomAddr = 'Y' THEN C_Address1 ELSE @c_S_Addr_L2 END   --WL01
        , C_Addr_L3 = CASE WHEN @c_CustomAddr = 'Y' THEN CASE WHEN ISNULL(C_Address4,'') = '' THEN C_City + ', ' + C_State + ', ' + C_Zip ELSE C_Address4 END ELSE @c_S_Addr_L3 END   --WL01
        , C_Addr_L4 = CASE WHEN @c_CustomAddr = 'Y' THEN CASE WHEN ISNULL(C_Address4,'') = '' THEN C_Country ELSE C_City + ', ' + C_State + ', ' + C_Zip END ELSE @c_S_Addr_L4 END   --WL01
        , C_Addr_L5 = CASE WHEN @c_CustomAddr = 'Y' THEN CASE WHEN ISNULL(C_Address4,'') = '' THEN '' ELSE C_Country END ELSE @c_S_Addr_L5 END   --WL01
        , ExternOrderKey
        , EffectiveDate
        , ConsigneeKey
        , BuyerPO
        , ORDAddDate
        , Adddate
        , DESCR
        , SKU = MANUFACTURERSKU
        , Size
        , OriginalQty = PDQty
        , Qty = PDQty
        , [Weight]
        , TTLCTN
        , C_Company
        , Style
        , UnshippedQty = 0
        , @c_Country_TXT AS Country_TXT
        , @c_Phone_TXT AS Phone_TXT
        , @c_Fax_TXT AS Fax_TXT
        , @c_FOOTER1_TXT AS FOOTER1_TXT
        , @c_FOOTER2_TXT AS FOOTER2_TXT
        , B_Addr_L1 = CASE WHEN @c_CustomAddr = 'Y' THEN B_Company + ' ' + B_Contact1 ELSE @c_B_Addr_L1 END   --WL01
        , B_Addr_L2 = CASE WHEN @c_CustomAddr = 'Y' THEN B_Address1 ELSE @c_B_Addr_L2 END   --WL01
        , B_Addr_L3 = CASE WHEN @c_CustomAddr = 'Y' THEN CASE WHEN ISNULL(B_Address2,'') = '' THEN B_City + ', ' + B_State + ', ' + B_Zip ELSE B_Address2 END ELSE @c_B_Addr_L3 END   --WL01
        , B_Addr_L4 = CASE WHEN @c_CustomAddr = 'Y' THEN CASE WHEN ISNULL(B_Address2,'') = '' THEN B_Country ELSE B_City + ', ' + B_State + ', ' + B_Zip END ELSE @c_B_Addr_L4 END   --WL01
        , B_Addr_L5 = CASE WHEN @c_CustomAddr = 'Y' THEN CASE WHEN ISNULL(B_Address2,'') = '' THEN '' ELSE B_Country END ELSE @c_B_Addr_L5 END   --WL01
        , @c_Email_TXT AS Email_TXT
        , @c_Remark_TXT AS Remark_TXT
   FROM #T_RESULT
   ORDER BY LabelNo
          , Style
          , MANUFACTURERSKU
          , Size
END

GO