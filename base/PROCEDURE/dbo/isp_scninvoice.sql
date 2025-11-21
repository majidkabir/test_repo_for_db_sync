SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_SCNInvoice                                     */  
/* Creation Date: 25-June-2013                                          */  
/* Copyright: IDS                                                       */  
/* Written by: GTGOH                                                    */  
/*                                                                      */  
/* Purpose:  SOS#281430 - Carton Label Printing for Carters             */  
/*                                                                      */  
/* Called By:  WMS - Print SCN Invoice                                  */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 23-Aug-2013  YTWan     1.1   SOS#287325:keep the same sequence for   */
/*                              PickingSlip Report & Invoice Report.    */
/*                              (Wan01)                                 */
/* 11-Nov-2013  KTLow     1.2   SOS#287325:change sequence sorting for  */
/*                              sum(PickDetail.Qty) > 1 (KT01)          */
/* 25-Nov-2013  YTWan     1.3   SOS#295714:SCN -- CR for InvoiceReport  */
/*                              SP 20131119 (Wan02)                     */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_SCNInvoice] (  
            @c_StorerKey    NVARCHAR(15)  --'18422'
          , @c_LoadKey      NVARCHAR(10)
          , @c_OrderKey     NVARCHAR(10)
          , @c_UserDefine03 NVARCHAR(20)
          , @c_Shipperkey   NVARCHAR(15)
          , @c_PickQty      INT           --'1','2'
          , @c_InvoiceCode  NVARCHAR(20)  --'SCN01'
          , @c_InvoiceNo    NVARCHAR(20)
         )  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @b_debug INT  
   SET @b_debug = 0  
/*********************************************/  
/* Variables Declaration (Start)             */  
/*********************************************/
   -- Extract from General  
   DECLARE @c_SUSR1              NVARCHAR(20)   
         , @c_CustomerGroupName  NVARCHAR(60)   
         , @c_M_Company          NVARCHAR(45)
         , @c_OrderInfo          NVARCHAR(150)
         , @c_OrderInfo_No       NVARCHAR(20)  
         , @c_OrderInfo_Amt      NVARCHAR(20)  
         , @c_OrderInfo_Type     NVARCHAR(20) 
         , @c_OrderInfo_Title    NVARCHAR(32)  
         , @c_OrderInfo_Content  NVARCHAR(64)  
         , @n_RowCount           INT  
         , @n_InfoCount          INT  
         , @c_Note2              NVARCHAR(4000)
         , @dt_GetDate           DATETIME
         , @c_GetDate            NVARCHAR(14)
         , @c_PrintDate          NVARCHAR(20)
         , @c_Business           NVARCHAR(10)
         , @c_Unit               NVARCHAR(10)
         , @c_Qty                NVARCHAR(10)
         , @c_PriceSign          NVARCHAR(16)
         , @n_InvoiceNoLength    INT
         , @c_RunningInvoiceNo   NVARCHAR(30)
         , @n_InvoiceCount       INT

   -- Variables Initialization  
   SET @c_SUSR1               = ''
   SET @c_CustomerGroupName   = ''
   SET @c_M_Company           = ''
   SET @c_OrderInfo           = ''
   SET @c_OrderInfo_No        = ''
   SET @c_OrderInfo_Amt       = ''
   SET @c_OrderInfo_Type      = ''
   SET @c_OrderInfo_Title     = ''
   SET @c_OrderInfo_Content   = ''
   SET @n_RowCount            = 0
   SET @n_InfoCount           = 0
   SET @c_Note2        = ''
   SET @dt_GetDate            = GETDATE()
   SET @c_GetDate             = CONVERT(NVARCHAR(8), @dt_Getdate, 112)

   SET @c_PrintDate           = SUBSTRING(@c_GetDate, 1, 4) + N'年' + 
       SUBSTRING(@c_GetDate, 5, 2) + N'月' + 
                                SUBSTRING(@c_GetDate, 7, 2) + N'日'
   SET @c_Business            = N'商业'
   SET @c_Unit                = N'批'
   SET @c_Qty                 = '1'
   SET @c_PriceSign           = N'￥'
   SET @n_InvoiceNoLength     = 0
   SET @c_RunningInvoiceNo    = ''
   SET @n_InvoiceCount        = 0
/*********************************************/  
/* Variables Declaration (End)               */  
/*********************************************/ 
/*********************************************/  
/* Validation (Start)                        */  
/*********************************************/ 
   IF RTRIM(ISNULL(@c_LoadKey,'')) = '' AND RTRIM(ISNULL(@c_OrderKey,'')) = ''
   BEGIN
      GOTO QUIT
   END 

   IF ISNUMERIC(@c_InvoiceNo) = 0
   BEGIN
      GOTO QUIT
   END

   SET @n_InvoiceNoLength = LEN(@c_InvoiceNo)

   IF ISNULL(RTRIM(@c_InvoiceCode), '') = ''
      SET @c_InvoiceCode = 'SCN01'

   SELECT DISTINCT @c_StorerKey = StorerKey   
   FROM ORDERS WITH (NOLOCK)  
   WHERE ORDERS.OrderKey = @c_OrderKey  
/*********************************************/  
/* Validation (End)                          */   
/*********************************************/
/*********************************************/  
/* Temp Tables Creation (Start)              */  
/*********************************************/  

   IF @b_debug = 1
   BEGIN  
      SELECT 'Creat Temp tables - #TempSCNOrder...'  
   END  
  
   IF ISNULL(OBJECT_ID('tempdb..#TempSCNOrder'),'') <> ''  
      DROP TABLE #TempSCNOrder  
 
   IF ISNULL(OBJECT_ID('tempdb..#TempSCNOrder'),'') = ''  
   BEGIN
      CREATE TABLE #TempSCNOrder  
               (  RowNum                           INT NOT NULL,
                  Orders_StorerKey                 NVARCHAR(15) default '',          
                  Orders_OrderKey                  NVARCHAR(10) default '',          
                  Storer_SUSR1                     NVARCHAR(20) default '',          
                  CustomerGroupName                NVARCHAR(60) default '',          
                  Orders_M_Company                 NVARCHAR(45) default '',
                  Orders_Loc                       NVARCHAR(10) default '', 
                  Orders_Sku                       NVARCHAR(20) default '',
                  ORDERS_LogicalLocation           NVARCHAR(18) DEFAULT ''    --(Wan01)      
               )  CREATE UNIQUE CLUSTERED INDEX IX_1 on #TempSCNOrder (RowNum)
   END  
  
   IF @b_debug = 1
   BEGIN  
      SELECT 'Creat Temp tables - #TempSCNInvoice...'  
   END  
  
   IF ISNULL(OBJECT_ID('tempdb..#TempSCNInvoice'),'') <> ''  
      DROP TABLE #TempSCNInvoice  
  
   IF ISNULL(OBJECT_ID('tempdb..#TempSCNInvoice'),'') = ''  
   BEGIN  
  
      CREATE TABLE #TempSCNInvoice  
               (  RowNum                           INT IDENTITY(1,1)  NOT NULL,              --(Wan01)
                  Orders_StorerKey                 NVARCHAR(15) default '',          
                  Orders_OrderKey                  NVARCHAR(10) default '',          
                  Storer_SUSR1                     NVARCHAR(20) default '',          
                  CustomerGroupName                NVARCHAR(60) default '',          
                  Orders_M_Company                 NVARCHAR(45) default '',          
                  OrderInfo_No                     NVARCHAR(20) default '',          
                  OrderInfo_Amt                    NVARCHAR(20) default '',          
                  OrderInfo_Title                  NVARCHAR(32) default '',          
                  OrderInfo_Content                NVARCHAR(64) default ''
               )  
   END  
/*********************************************/  
/* Temp Tables Creation (End)                */  
/*********************************************/  
 DECLARE @n_RunNumber INT  
 SELECT @n_RunNumber = 0  
/*********************************************/  
/* Data extraction (Start)                   */  
/*********************************************/  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT 'Extract records INTo Temp table - #TempSCNOrder...'  
   END 

   --(Wan02) - START
   IF NOT EXISTS (SELECT 1
                  FROM CODELKUP WITH (NOLOCK)
                  WHERE ListName = 'SCNINVNO'
                  AND  Short = 'ACTIVE'
                  AND  Description = @c_InvoiceCode)
   BEGIN
      IF @b_debug = 1  
      BEGIN  
         SELECT 'Invoice # checking against codelkup - 1'  
      END 
      GOTO QUIT
   END

   IF NOT EXISTS (SELECT 1
                  FROM CODELKUP WITH (NOLOCK)
                  WHERE ListName = 'SCNINVNO'
                  AND  Short = 'ACTIVE'
                  AND  Description = @c_InvoiceCode
                  AND  UDF01 <= @c_InvoiceNo
                  AND  UDF02 >= @c_InvoiceNo)
   BEGIN
      IF @b_debug = 1  
      BEGIN  
         SELECT 'Invoice # checking against codelkup - 2'  
      END 
      GOTO QUIT
   END

   IF EXISTS (SELECT 1
              FROM ORDERS    OH WITH (NOLOCK)
              JOIN ORDERINFO OI WITH (NOLOCK) ON (OH.Orderkey = OI.Orderkey)
              WHERE OH.Storerkey = @c_Storerkey
              AND   OH.InvoiceNo = @c_InvoiceCode
              AND   OH.PrintFlag = '1'
              AND   (OI.OrderInfo01 = @c_InvoiceNo
              OR     OI.OrderInfo02 = @c_InvoiceNo
              OR     OI.OrderInfo03 = @c_InvoiceNo
              OR     OI.OrderInfo04 = @c_InvoiceNo
              OR     OI.OrderInfo05 = @c_InvoiceNo
              OR     OI.OrderInfo06 = @c_InvoiceNo
              OR     OI.OrderInfo07 = @c_InvoiceNo
              OR     OI.OrderInfo08 = @c_InvoiceNo
              OR     OI.OrderInfo09 = @c_InvoiceNo
              OR     OI.OrderInfo10 = @c_InvoiceNo))
   BEGIN
      IF @b_debug = 1  
      BEGIN  
         SELECT 'Invoice # checking against ORDERINFO Table'  
      END 
      GOTO QUIT
   END

   --(Wan02) - END

   IF @c_PickQty = '1' 
   BEGIN
      IF RTRIM(ISNULL(@c_OrderKey,'')) <> '' AND RTRIM(ISNULL(@c_OrderKey,'')) <> '0'
      BEGIN
         INSERT INTO #TempSCNOrder  
         ( RowNum
         , Orders_StorerKey            
         , Orders_OrderKey             
         , Storer_SUSR1                
         , CustomerGroupName    
         , Orders_M_Company
         , Orders_Loc
         , Orders_Sku
         --(Wan01) - START
         , ORDERS_LogicalLocation )                                        
         --SELECT DISTINCT ROW_NUMBER() OVER(ORDER BY MIN(RTRIM(ISNULL(PD.Loc,''))), 
         --       MIN(RTRIM(ISNULL(PD.Sku,''))), RTRIM(ISNULL(OH.OrderKey,''))) AS RowNum
         SELECT DISTINCT ROW_NUMBER() OVER(ORDER BY MIN(ISNULL(RTRIM(LOC.LogicalLocation),''))
                                                   ,MIN(RTRIM(ISNULL(PD.Loc,'')))  
                                                   ,RTRIM(ISNULL(OH.OrderKey,''))) AS RowNum
         --(Wan01) - END
               ,RTRIM(ISNULL(OH.StorerKey,''))
               ,RTRIM(ISNULL(OH.OrderKey,''))
               ,RTRIM(ISNULL(Storer.SUSR1,''))
               ,RTRIM(ISNULL(Storer.CustomerGroupName,''))
               ,RTRIM(ISNULL(OH.M_Company,''))
               ,MIN(RTRIM(ISNULL(PD.Loc,'')))
               ,MIN(RTRIM(ISNULL(PD.Sku,'')))
               ,MIN(ISNULL(RTRIM(LOC.LogicalLocation),''))                 --(Wan01)
         FROM ORDERS OH WITH(NOLOCK)
         JOIN Storer Storer WITH(NOLOCK)
         ON OH.StorerKey = Storer.StorerKey
         JOIN PICKDETAIL PD WITH(NOLOCK)
         ON OH.OrderKey = PD.OrderKey
         JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)                      --(Wan01)
         JOIN CODELKUP CLK WITH(NOLOCK) 
         ON (OH.Userdefine03 = CLK.Description 
         AND CLK.ListName = 'SCNSTORE' AND CLK.SHORT = @c_UserDefine03)
         WHERE OH.PrintFlag = '1'
         AND OH.Storerkey = @c_StorerKey
         AND OH.OrderKey = @c_OrderKey 
         AND OH.Shipperkey = @c_Shipperkey
         GROUP BY RTRIM(ISNULL(OH.StorerKey,''))
               ,RTRIM(ISNULL(OH.OrderKey,''))
               ,RTRIM(ISNULL(Storer.SUSR1,''))
               ,RTRIM(ISNULL(Storer.CustomerGroupName,''))
               ,RTRIM(ISNULL(OH.M_Company,''))
         HAVING SUM(PD.Qty) = 1
         ORDER BY MIN(ISNULL(RTRIM(LOC.LogicalLocation),''))               --(Wan01)
               ,MIN(RTRIM(ISNULL(PD.Loc,'')))
               --,MIN(RTRIM(ISNULL(PD.Sku,'')))                            --(Wan01)
               ,RTRIM(ISNULL(OH.OrderKey,''))
      END
      ELSE
      BEGIN
         INSERT INTO #TempSCNOrder  
         ( RowNum
         , Orders_StorerKey            
         , Orders_OrderKey             
         , Storer_SUSR1                
         , CustomerGroupName    
         , Orders_M_Company
         , Orders_Loc
         , Orders_Sku 
         --(Wan01) - START
         , ORDERS_LogicalLocation )                                        
--         SELECT DISTINCT ROW_NUMBER() OVER(ORDER BY MIN(RTRIM(ISNULL(PD.Loc,''))), MIN(RTRIM(ISNULL(PD.Sku,''))), RTRIM(ISNULL(OH.OrderKey,''))) AS RowNum
         SELECT DISTINCT ROW_NUMBER() OVER(ORDER BY MIN(ISNULL(RTRIM(LOC.LogicalLocation),''))
                                                   ,MIN(RTRIM(ISNULL(PD.Loc,'')))  
                                                   ,RTRIM(ISNULL(OH.OrderKey,''))) AS RowNum
         --(Wan01) - END
               ,RTRIM(ISNULL(OH.StorerKey,''))
               ,RTRIM(ISNULL(OH.OrderKey,''))
               ,RTRIM(ISNULL(Storer.SUSR1,''))
               ,RTRIM(ISNULL(Storer.CustomerGroupName,''))
               ,RTRIM(ISNULL(OH.M_Company,''))
               ,MIN(RTRIM(ISNULL(PD.Loc,'')))
               ,MIN(RTRIM(ISNULL(PD.Sku,'')))
               ,MIN(ISNULL(RTRIM(LOC.LogicalLocation),''))                 --(Wan01)
         FROM ORDERS OH WITH(NOLOCK)
         JOIN Storer Storer WITH(NOLOCK)
         ON OH.StorerKey = Storer.StorerKey
         JOIN PICKDETAIL PD WITH(NOLOCK)
         ON OH.OrderKey = PD.OrderKey
         JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)                      --(Wan01)
         JOIN CODELKUP CLK WITH(NOLOCK) 
         ON (OH.Userdefine03 = CLK.Description 
         AND CLK.ListName = 'SCNSTORE' AND CLK.SHORT = @c_UserDefine03)
         WHERE OH.PrintFlag = '1'
         AND OH.Storerkey = @c_StorerKey
         AND OH.Loadkey = @c_LoadKey 
         AND OH.Shipperkey = @c_Shipperkey
         GROUP BY RTRIM(ISNULL(OH.StorerKey,''))
               ,RTRIM(ISNULL(OH.OrderKey,''))
               ,RTRIM(ISNULL(Storer.SUSR1,''))
               ,RTRIM(ISNULL(Storer.CustomerGroupName,''))
               ,RTRIM(ISNULL(OH.M_Company,''))
         HAVING SUM(PD.Qty) = 1
         ORDER BY MIN(ISNULL(RTRIM(LOC.LogicalLocation),''))               --(Wan01)
               ,MIN(RTRIM(ISNULL(PD.Loc,'')))
               --,MIN(RTRIM(ISNULL(PD.Sku,'')))                            --(Wan01)
               ,RTRIM(ISNULL(OH.OrderKey,''))
      END
   END
   ELSE
   BEGIN   
      IF RTRIM(ISNULL(@c_OrderKey,'')) <> '' AND RTRIM(ISNULL(@c_OrderKey,'')) <> '0' 
      BEGIN
         INSERT INTO #TempSCNOrder  
         ( RowNum
         , Orders_StorerKey            
         , Orders_OrderKey             
         , Storer_SUSR1                
         , CustomerGroupName    
         , Orders_M_Company
         , Orders_Loc
         , Orders_Sku 
         --(Wan01) - START
         , ORDERS_LogicalLocation )                                        
--         SELECT DISTINCT ROW_NUMBER() OVER(ORDER BY MIN(RTRIM(ISNULL(PD.Loc,''))), 
--                MIN(RTRIM(ISNULL(PD.Sku,''))), RTRIM(ISNULL(OH.OrderKey,''))) AS RowNum
         --(KT01) - Start
--         SELECT DISTINCT ROW_NUMBER() OVER(ORDER BY MIN(ISNULL(RTRIM(LOC.LogicalLocation),''))
--                                                   ,MIN(RTRIM(ISNULL(PD.Loc,'')))  
--                                                   ,RTRIM(ISNULL(OH.OrderKey,''))) AS RowNum

         SELECT DISTINCT ROW_NUMBER() OVER(ORDER BY RTRIM(ISNULL(OH.OrderKey,''))) AS RowNum
         --(KT01) - End
         --(Wan01) - END
               ,RTRIM(ISNULL(OH.StorerKey,''))
               ,RTRIM(ISNULL(OH.OrderKey,''))
               ,RTRIM(ISNULL(Storer.SUSR1,''))
               ,RTRIM(ISNULL(Storer.CustomerGroupName,''))
               ,RTRIM(ISNULL(OH.M_Company,''))
               ,MIN(RTRIM(ISNULL(PD.Loc,'')))
               ,MIN(RTRIM(ISNULL(PD.Sku,'')))
               ,MIN(ISNULL(RTRIM(LOC.LogicalLocation),''))                 --(Wan01)
         FROM ORDERS OH WITH(NOLOCK)
         JOIN Storer Storer WITH(NOLOCK)
         ON OH.StorerKey = Storer.StorerKey
         JOIN PICKDETAIL PD WITH(NOLOCK)
         ON OH.OrderKey = PD.OrderKey
         JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)                      --(Wan01)
         JOIN CODELKUP CLK WITH(NOLOCK) 
         ON (OH.Userdefine03 = CLK.Description 
         AND CLK.ListName = 'SCNSTORE' AND CLK.SHORT = @c_UserDefine03)
         WHERE OH.PrintFlag = '1'
         AND OH.Storerkey = @c_StorerKey
         AND OH.OrderKey = @c_OrderKey 
         AND OH.Shipperkey = @c_Shipperkey
         GROUP BY RTRIM(ISNULL(OH.StorerKey,''))
               ,RTRIM(ISNULL(OH.OrderKey,''))
               ,RTRIM(ISNULL(Storer.SUSR1,''))
               ,RTRIM(ISNULL(Storer.CustomerGroupName,''))
               ,RTRIM(ISNULL(OH.M_Company,''))
         HAVING SUM(PD.Qty) > 1
         --(KT01) - Start
--         ORDER BY MIN(ISNULL(RTRIM(LOC.LogicalLocation),''))   --(Wan01)
--               ,MIN(RTRIM(ISNULL(PD.Loc,'')))
--               --,MIN(RTRIM(ISNULL(PD.Sku,'')))                            --(Wan01)
--               ,RTRIM(ISNULL(OH.OrderKey,''))

         ORDER BY RTRIM(ISNULL(OH.OrderKey,''))
         --(KT01) - End

      END
      ELSE
      BEGIN
         INSERT INTO #TempSCNOrder  
         ( RowNum
         , Orders_StorerKey           
         , Orders_OrderKey             
         , Storer_SUSR1                
         , CustomerGroupName    
         , Orders_M_Company
         , Orders_Loc
         , Orders_Sku 
         --(Wan01) - START
         , ORDERS_LogicalLocation )                                        
--         SELECT DISTINCT ROW_NUMBER() OVER(ORDER BY MIN(RTRIM(ISNULL(PD.Loc,''))), 
--                MIN(RTRIM(ISNULL(PD.Sku,''))), RTRIM(ISNULL(OH.OrderKey,''))) AS RowNum
         --(KT01) - Start
--         SELECT DISTINCT ROW_NUMBER() OVER(ORDER BY MIN(ISNULL(RTRIM(LOC.LogicalLocation),''))
--                                                   ,MIN(RTRIM(ISNULL(PD.Loc,'')))  
--                                                   ,RTRIM(ISNULL(OH.OrderKey,''))) AS RowNum
         SELECT DISTINCT ROW_NUMBER() OVER(ORDER BY RTRIM(ISNULL(OH.OrderKey,''))) AS RowNum
         --(KT01) - End
         --(Wan01) - END
               ,RTRIM(ISNULL(OH.StorerKey,''))
               ,RTRIM(ISNULL(OH.OrderKey,''))
               ,RTRIM(ISNULL(Storer.SUSR1,''))
               ,RTRIM(ISNULL(Storer.CustomerGroupName,''))
               ,RTRIM(ISNULL(OH.M_Company,''))
               ,MIN(RTRIM(ISNULL(PD.Loc,'')))
               ,MIN(RTRIM(ISNULL(PD.Sku,'')))
               ,MIN(ISNULL(RTRIM(LOC.LogicalLocation),''))                 --(Wan01)
         FROM ORDERS OH WITH(NOLOCK)
         JOIN Storer Storer WITH(NOLOCK)
         ON OH.StorerKey = Storer.StorerKey
         JOIN PICKDETAIL PD WITH(NOLOCK)
         ON OH.OrderKey = PD.OrderKey
         JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)                      --(Wan01)
         JOIN CODELKUP CLK WITH(NOLOCK) 
         ON (OH.Userdefine03 = CLK.Description 
         AND CLK.ListName = 'SCNSTORE' AND CLK.SHORT = @c_UserDefine03)
         WHERE OH.PrintFlag = '1'
         AND OH.Storerkey = @c_StorerKey
         AND OH.Loadkey = @c_LoadKey 
         AND OH.Shipperkey = @c_Shipperkey
         GROUP BY RTRIM(ISNULL(OH.StorerKey,''))
               ,RTRIM(ISNULL(OH.OrderKey,''))
               ,RTRIM(ISNULL(Storer.SUSR1,''))
               ,RTRIM(ISNULL(Storer.CustomerGroupName,''))
               ,RTRIM(ISNULL(OH.M_Company,''))
         HAVING SUM(PD.Qty) > 1
         --(KT01) - Start
--         ORDER BY MIN(ISNULL(RTRIM(LOC.LogicalLocation),''))               --(Wan01)
--               ,MIN(RTRIM(ISNULL(PD.Loc,'')))
--               --,MIN(RTRIM(ISNULL(PD.Sku,'')))                            --(Wan01)
--               ,RTRIM(ISNULL(OH.OrderKey,''))
         ORDER BY RTRIM(ISNULL(OH.OrderKey,''))
         --(KT01) - End
      END
   END

   IF @b_debug = 1  
   BEGIN  
      SELECT '#TempSCNOrder.. '  
      SELECT * FROM #TempSCNOrder  
   END  
     
/*********************************************/  
/* Data extraction (Start)                   */  
/*********************************************/  
/*********************************************/  
/* Cursor Loop - OrderInfo Insertion (Start) */  
/*********************************************/  
   SET @n_InvoiceCount = 0

   DECLARE OrderInfo_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT Orders_StorerKey
        , Orders_OrderKey
        , Storer_SUSR1                 
        , CustomerGroupName
        , Orders_M_Company 
   FROM #TempSCNOrder (NOLOCK) 
   JOIN LOC WITH (NOLOCK) ON (#TempSCNOrder.Orders_Loc = LOC.Loc)  
   Order By RowNum
     
   OPEN OrderInfo_Cur  
   FETCH NEXT FROM OrderInfo_Cur INTO @c_StorerKey
                                    , @c_OrderKey
                                    , @c_SUSR1
                                    , @c_CustomerGroupName
                                    , @c_M_Company        
 
     
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN 

      SELECT @c_Note2 = RTRIM(ISNULL(Notes2,'')) FROM ORDERS WITH(NOLOCK) WHERE StorerKey = @c_StorerKey AND OrderKey = @c_OrderKey
      SET @n_RowCount = 0

      IF @b_debug = 1
      BEGIN
         PRINT '@c_Note2=' + @c_Note2
         PRINT '@c_CharIndex=' + CAST(CAST(CHARINDEX('[<',@c_Note2) AS INT)AS NVARCHAR)
      END

      WHILE CHARINDEX('[<',@c_Note2) <> 0
      BEGIN
         SET @n_InvoiceCount = @n_InvoiceCount + 1
         SET @n_RowCount = @n_RowCount + 1
         SET @c_OrderInfo = ''
         SET @c_OrderInfo_No = ''
         SET @c_OrderInfo_Amt = '0'
         SET @c_OrderInfo_Type = ''
         SET @c_OrderInfo_Title = ''
         SET @c_OrderInfo_Content = ''
         SET @c_RunningInvoiceNo = ''

         SET @c_OrderInfo = SUBSTRING(@c_Note2, CHARINDEX('[<',@c_Note2)+2, CHARINDEX('>]',@c_Note2) - CHARINDEX('[<',@c_Note2)-2)
         SET @c_Note2 = SUBSTRING(@c_Note2, LEN(RTRIM(@c_OrderInfo))+ 5,LEN(RTRIM(@c_Note2))-LEN(RTRIM(@c_OrderInfo))-4)
         SET @n_InfoCount = 0

         IF @b_debug = 1
         BEGIN
            PRINT '@n_RowCount=' + CAST(CAST(@n_RowCount AS INT)AS NVARCHAR)
            PRINT '@n_InvoiceCount=' + CAST(CAST(@n_InvoiceCount AS INT)AS NVARCHAR)
            PRINT '@c_OrderInfo=' + @c_OrderInfo
            PRINT '@c_Note2=' + @c_Note2
         END

         IF @n_InvoiceCount = 1
         BEGIN
            SET @c_RunningInvoiceNo = @c_InvoiceNo
         END
         ELSE
         BEGIN
            SET @c_RunningInvoiceNo = CAST(CAST((CONVERT(INT, @c_InvoiceNo) + 1) AS INT) AS NVARCHAR) 
            SET @c_InvoiceNo = @c_RunningInvoiceNo

		      SET @c_RunningInvoiceNo = RIGHT('0000000000' + @c_RunningInvoiceNo, @n_InvoiceNoLength)
         END

         SET @c_OrderInfo_No = SUBSTRING(@c_OrderInfo, 1, CHARINDEX('^^^',@c_OrderInfo) - 1)
      
         WHILE CHARINDEX('^^^',@c_OrderInfo) <> 0
         BEGIN
            SET @c_OrderInfo = SUBSTRING(@c_OrderInfo,CHARINDEX('^^^',@c_OrderInfo) + 3, 
                               LEN(@c_OrderInfo) - CHARINDEX('^^^',@c_OrderInfo)+ 3)

            SET @n_InfoCount = @n_InfoCount + 1

            IF @n_InfoCount = 1  
               SET @c_OrderInfo_Amt =  CASE CHARINDEX('^^^',@c_OrderInfo) WHEN 1 THEN ''
                                       ELSE SUBSTRING(@c_OrderInfo,1, CHARINDEX('^^^',@c_OrderInfo)-1) END

            IF @n_InfoCount = 2
               SET @c_OrderInfo_Type =   CASE CHARINDEX('^^^',@c_OrderInfo) WHEN 1 THEN ''
                                          ELSE SUBSTRING(@c_OrderInfo,1, CHARINDEX('^^^',@c_OrderInfo)-1) END

            IF @n_InfoCount = 3
               SET @c_OrderInfo_Title =   CASE CHARINDEX('^^^',@c_OrderInfo) WHEN 1 THEN ''
                                          ELSE SUBSTRING(@c_OrderInfo,1, CHARINDEX('^^^',@c_OrderInfo)-1) END

               SET @c_OrderInfo_Content = @c_OrderInfo

            IF @n_InfoCount = 4
               SET @c_OrderInfo_Content = @c_OrderInfo
         END --WHILE CHARINDEX('^^^',@c_OrderInfo) <> 0

         IF @b_debug = 1
         BEGIN
            PRINT '@c_InvoiceNo=' + @c_InvoiceNo
            PRINT '@c_RunningInvoiceNo=' + @c_RunningInvoiceNo
            PRINT '@c_OrderInfo_No=' + @c_OrderInfo_No
            PRINT '@c_OrderInfo_Amt=' + @c_OrderInfo_Amt
            PRINT '@c_OrderInfo_Type=' + @c_OrderInfo_Type
            PRINT '@c_OrderInfo_Title=' + @c_OrderInfo_Title
            PRINT '@c_OrderInfo_Content=' + @c_OrderInfo_Content
         END

         INSERT INTO #TempSCNInvoice  
         ( 
            Orders_StorerKey   
           ,Orders_OrderKey  
           ,Storer_SUSR1
           ,CustomerGroupName  
           ,Orders_M_Company 
           ,OrderInfo_No
           ,OrderInfo_Amt      
           ,OrderInfo_Title  
           ,OrderInfo_Content 
         )    
         VALUES 
         (
            @c_StorerKey       
           ,@c_OrderKey      
           ,@c_SUSR1
           ,@c_CustomerGroupName     
           ,@c_M_Company             
           ,@c_OrderInfo_No      
           ,@c_OrderInfo_Amt            
           ,@c_OrderInfo_Title          
           ,@c_OrderInfo_Content 
         )

         IF @n_RowCount = 1
         BEGIN
            DELETE FROM OrderInfo WITH(ROWLOCK) WHERE OrderKey = @c_OrderKey

            INSERT INTO OrderInfo 
            (OrderKey, OrderInfo01)
            VALUES(@c_OrderKey, @c_RunningInvoiceNo) 
         END
         ELSE
         BEGIN
            IF @n_RowCount = 2
               UPDATE OrderInfo WITH(ROWLOCK) 
               SET OrderInfo02 = @c_RunningInvoiceNo
               WHERE OrderKey = @c_OrderKey
            ELSE IF @n_RowCount = 3
               UPDATE OrderInfo WITH(ROWLOCK) 
               SET OrderInfo03 = @c_RunningInvoiceNo
               WHERE OrderKey = @c_OrderKey
            ELSE IF @n_RowCount = 4
               UPDATE OrderInfo WITH(ROWLOCK) 
               SET OrderInfo04 = @c_RunningInvoiceNo
               WHERE OrderKey = @c_OrderKey
            ELSE IF @n_RowCount = 5
               UPDATE OrderInfo WITH(ROWLOCK) 
               SET OrderInfo05 = @c_RunningInvoiceNo
               WHERE OrderKey = @c_OrderKey
            ELSE IF @n_RowCount = 6
               UPDATE OrderInfo WITH(ROWLOCK) 
               SET OrderInfo06 = @c_RunningInvoiceNo
               WHERE OrderKey = @c_OrderKey
            ELSE IF @n_RowCount = 7
               UPDATE OrderInfo WITH(ROWLOCK) 
               SET OrderInfo07 = @c_RunningInvoiceNo
               WHERE OrderKey = @c_OrderKey
            ELSE IF @n_RowCount = 8
               UPDATE OrderInfo WITH(ROWLOCK) 
               SET OrderInfo08 = @c_RunningInvoiceNo
               WHERE OrderKey = @c_OrderKey
            ELSE IF @n_RowCount = 9
               UPDATE OrderInfo WITH(ROWLOCK) 
               SET OrderInfo09 = @c_RunningInvoiceNo
               WHERE OrderKey = @c_OrderKey
            ELSE IF @n_RowCount = 10
               UPDATE OrderInfo WITH(ROWLOCK) 
               SET OrderInfo10 = @c_RunningInvoiceNo
               WHERE OrderKey = @c_OrderKey
         END

         UPDATE ORDERS WITH (ROWLOCK)
         SET InvoiceNo = @c_InvoiceCode,
             PrintDocDate = GETDATE(),             ---(Wan02)
             TrafficCop = NULL,
             EditDate = GETDATE(),
             EditWho = SUSER_NAME()
         WHERE OrderKey = @c_OrderKey
      END
      FETCH NEXT FROM OrderInfo_Cur INTO @c_StorerKey
                                       , @c_OrderKey
                                       , @c_SUSR1
                                       , @c_CustomerGroupName
                                       , @c_M_Company
   END 
   CLOSE OrderInfo_Cur  
   DEALLOCATE OrderInfo_Cur

   QUIT: 
   SELECT Orders_OrderKey AS OrderKey
         ,OrderInfo_No AS OrderInfo_No
         ,@c_PrintDate AS PrintDate
         ,@c_Business AS Business
         ,OrderInfo_Title
         ,OrderInfo_Content 
         ,@c_Unit AS Unit
         ,@c_Qty AS Qty
         ,OrderInfo_Amt AS UnitPrice
         ,OrderInfo_Amt AS Tot_Price
         --,master.dbo.fn_ConvertNumCHN(OrderInfo_Amt)  AS Price_Capital
         ,dbo.fn_ConvertNumCHN(OrderInfo_Amt)  AS Price_Capital
         ,@c_PriceSign + OrderInfo_Amt AS Price_LowerCase
         ,CustomerGroupName AS CompanyName
         ,Storer_SUSR1 AS Company_Code
         ,Orders_M_Company AS OrderNo
   FROM #TempSCNInvoice WITH(NOLOCK)
   ORDER BY RowNum                        --(Wan01)                                                     
 


   IF OBJECT_ID('tempdb..#TempSCNOrder') IS NOT NULL 
   BEGIN
      DROP Table #TempSCNOrder
   END  

   IF OBJECT_ID('tempdb..#TempSCNInvoice') IS NOT NULL 
   BEGIN
      DROP Table #TempSCNInvoice
   END 
END  
 

GO