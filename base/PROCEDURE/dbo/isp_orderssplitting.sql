SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
        
/*----------------------------------------------------------------------------------------------------------------------*/        
/* Stored Procedure: isp_OrdersSplitting                                                                                */        
/* Creation Date: 09-Oct-2020                                                                                           */        
/* Copyright: LF LOGISTICS                                                                                              */        
/* Written by: JoshYan                                                                                                  */        
/*                                                                                                                      */        
/* Purpose: Auto Split Order data when there are different category in same order base on codelkup columns              */        
/*                                                                                                                      */        
/* Called By:                                                                                                           */        
/*                                                                                                                      */        
/* Parameters:                                                                                                          */        
/*                                                                                                                      */        
/* PVCS Version: 1.0                                                                                                    */        
/*                                                                                                                      */        
/* Version: 5.4                                                                                                         */        
/*                                                                                                                      */        
/* Data Modifications:                                                                                                  */        
/*                                                                                                                      */        
/* Updates:                                                                                                             */        
/* Date         Author    Ver. Purposes                                                                                 */        
/* 09-Oct-2020  JoshYan    1.0  UA Split Order for Referance                                                            */        
/* 15-Oct-2020  Shong      1.1  Performance Tuning                                                                      */        
/*----------------------------------------------------------------------------------------------------------------------*/        
CREATE PROCEDURE [dbo].[isp_OrdersSplitting] (        
@c_StorerKey nvarchar(15),        
@b_debug int = 0, --(1 for on, 0 for off, default 0)                          
@c_errmsg nvarchar(128) = '' OUTPUT)        
AS        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   BEGIN        
        
      DECLARE @c_SValue nvarchar(1),        
              @n_continue int,        
              @c_OrderKey nvarchar(10),        
              @c_OrderLineNo nvarchar(5),        
              @c_SplitType nvarchar(60),        
              @n_SplitNum int,        
              @n_Row_No int,        
              @c_NewOrderkey nvarchar(10),        
              @b_success int,        
              @n_err int,        
              @n_StartTCnt int,        
              @n_Notes2 nvarchar(4000),        
              @c_PickZone nvarchar(25)        
        
        
        
      /********** Initial parameter values **************/        
      SELECT        
         @c_SValue = NULL        
      SELECT        
         @n_continue = 1,        
         @b_success = 0,        
         @n_err = 0        
      SET @n_StartTCnt = @@ROWCOUNT        
       
      /********* StorerConfig checking *********/        
      SET @c_SValue = '0'        
      SELECT        
         @c_SValue = ISNULL(SVALUE,'0')         
      FROM StorerConfig WITH (NOLOCK)        
      WHERE ConfigKey = 'ORDSPLT'        
      AND Storerkey = @c_StorerKey        
        
      IF (@c_SValue <> '1')        
      BEGIN        
         SET @n_continue = 3        
         SET @c_errmsg = N'FAIL SPLITTING. ConfigKey ''ORDSPLT'' for storerkey''' + @c_StorerKey        
         + ''' is Turn OFF. Refer StorerConfig Table'        
         IF (@b_debug = 1)        
         BEGIN        
            SELECT        
               'SVALUE = ' + @c_SValue        
         END        
         GOTO EXIT_SP        
      END        
        
      IF ISNULL(OBJECT_ID('tempdb..#Temp_FinalOrders'), '') <> ''        
      BEGIN        
         DROP TABLE #Temp_FinalOrders        
      END        
        
      /********* Create Temp Tables *********/        
      CREATE TABLE #Temp_FinalOrders (        
         OrderKey nvarchar(10),        
         ExternOrderKey nvarchar(50),        
         M_Company nvarchar(45),      
         ShipperKey nvarchar(15), --Josh, add for filter courier, since some courier not support split order    
         SplitNum int        
      )        
        
      IF ISNULL(OBJECT_ID('tempdb..#temp_SplitOrderLines'), '') <> ''        
      BEGIN        
         DROP TABLE #temp_SplitOrderLines        
      END        
        
      CREATE TABLE #temp_SplitOrderLines (        
         OrderKey nvarchar(10),        
         OrderLineNumber nvarchar(5),        
         ExternOrderKey nvarchar(50),        
         M_Company nvarchar(45),        
         SplitType nvarchar(60),        
         Row_No int        
      )        
        
        
      IF ISNULL(OBJECT_ID('tempdb..#temp_OrderDetail'), '') <> ''        
      BEGIN        
         DROP TABLE #temp_OrderDetail        
      END        
        
      CREATE TABLE #temp_OrderDetail (        
         [ROW_NO] INT,        
       [OrderKey] [nvarchar](10) NOT NULL,        
       [OrderLineNumber] [nvarchar](5) NOT NULL,        
       [ExternOrderKey] [nvarchar](50) NOT NULL,        
       [ExternLineNo] [nvarchar](20) NOT NULL,        
       [Sku] [nvarchar](20) NOT NULL,        
       [StorerKey] [nvarchar](15) NOT NULL,        
       [ManufacturerSku] [nvarchar](20) NOT NULL,        
       [RetailSku] [nvarchar](20) NOT NULL,        
       [AltSku] [nvarchar](20) NOT NULL,        
       [OriginalQty] [int] NOT NULL,        
       [OpenQty] [int] NOT NULL,        
       [ShippedQty] [int] NOT NULL,        
       [AdjustedQty] [int] NOT NULL,        
       [QtyPreAllocated] [int] NOT NULL,        
       [QtyAllocated] [int] NOT NULL,        
       [QtyPicked] [int] NOT NULL,        
       [UOM] [nvarchar](10) NOT NULL,        
       [PackKey] [nvarchar](10) NOT NULL,        
       [PickCode] [nvarchar](10) NOT NULL,        
       [CartonGroup] [nvarchar](10) NOT NULL,        
       [Lot] [nvarchar](10) NOT NULL,        
       [ID] [nvarchar](18) NOT NULL,        
       [Facility] [nvarchar](5) NOT NULL,        
       [Status] [nvarchar](10) NOT NULL,        
       [UnitPrice] [float] NULL,        
       [Tax01] [float] NULL,        
       [Tax02] [float] NULL,        
       [ExtendedPrice] [float] NULL,        
       [UpdateSource] [nvarchar](10) NOT NULL,        
       [Lottable01] [nvarchar](18) NOT NULL,        
       [Lottable02] [nvarchar](18) NOT NULL,        
       [Lottable03] [nvarchar](18) NOT NULL,        
       [Lottable04] [datetime] NULL,        
       [Lottable05] [datetime] NULL,        
       [AddDate] [datetime] NOT NULL,        
       [AddWho] [nvarchar](128) NOT NULL,        
       --[EditDate] [datetime] NOT NULL,        
       --[EditWho] [nvarchar](128) NOT NULL,  --Josh      
       [FreeGoodQty] [int] NULL,        
       [GrossWeight] [float] NULL,        
       [Capacity] [float] NULL,        
       [QtyToProcess] [int] NULL,        
       [MinShelfLife] [int] NULL,        
       [UserDefine01] [nvarchar](18) NULL,        
       [UserDefine02] [nvarchar](18) NULL,        
       [UserDefine03] [nvarchar](18) NULL,        
       [UserDefine04] [nvarchar](18) NULL,        
       [UserDefine05] [nvarchar](18) NULL,        
       [UserDefine06] [nvarchar](18) NULL,        
       [UserDefine07] [nvarchar](18) NULL,        
       [UserDefine08] [nvarchar](18) NULL,        
       [UserDefine09] [nvarchar](18) NULL,        
       [POkey] [nvarchar](20) NULL,        
       [ExternPOKey] [nvarchar](20) NULL,        
       [UserDefine10] [nvarchar](18) NULL,        
       [EnteredQTY] [int] NULL,        
       [ConsoOrderKey] [nvarchar](30) NULL,        
       [ExternConsoOrderKey] [nvarchar](30) NULL,        
       [ConsoOrderLineNo] [nvarchar](5) NULL,        
       [Lottable06] [nvarchar](30) NOT NULL,        
       [Lottable07] [nvarchar](30) NOT NULL,        
       [Lottable08] [nvarchar](30) NOT NULL,        
       [Lottable09] [nvarchar](30) NOT NULL,        
       [Lottable10] [nvarchar](30) NOT NULL,        
       [Lottable11] [nvarchar](30) NOT NULL,        
       [Lottable12] [nvarchar](30) NOT NULL,        
       [Lottable13] [datetime] NULL,        
       [Lottable14] [datetime] NULL,        
       [Lottable15] [datetime] NULL,        
       [Notes] [nvarchar](500) NULL,        
       [Notes2] [nvarchar](500) NULL,        
       [Channel] [nvarchar](20) NULL         
         )         
           
      --SELECT        
      --   OrderKey,        
      --   OrderLineNumber,        
      --   ExternOrderKey,        
      --   ExternLineNo,        
      --   StorerKey,        
      --   Sku,        
      --   ManufacturerSku,        
      --   RetailSku,        
      --   AltSku,        
      --   OriginalQty,        
      --   OpenQty,        
      --   ShippedQty,        
      --   AdjustedQty,        
      --   QtyPreAllocated,        
      --   QtyAllocated,        
      --   QtyPicked,        
      --   UOM,        
      --   PackKey,        
      --   PickCode,        
      --   CartonGroup,        
      --   Lot,        
      --   ID,        
      --   Facility,        
      --   [Status],        
      --   UnitPrice,        
      --   Tax01,        
      --   Tax02,        
      --   ExtendedPrice,        
      --   UpdateSource,        
      --   Lottable01,        
      --   Lottable02,        
      --   Lottable03,        
      --   Lottable04,        
      --   Lottable05,        
      --   AddDate,        
      --   AddWho,        
      --   FreeGoodQty,        
      --   GrossWeight,        
      --   Capacity,        
      --   QtyToProcess,        
      --   MinShelfLife,        
      --   UserDefine01,        
      --   UserDefine02,        
      --   UserDefine03,        
      --   UserDefine04,        
      --   UserDefine05,        
      --   UserDefine06,        
      --   UserDefine07,        
      --   UserDefine08,        
      --   UserDefine09,        
      --   POkey,        
      --   ExternPOKey,        
      --   UserDefine10,        
      --   EnteredQTY,        
      --   ConsoOrderKey,        
      --   ExternConsoOrderKey,        
      --   ConsoOrderLineNo,        
      --   Lottable06,        
      --   Lottable07,        
      --   Lottable08,        
      --   Lottable09,        
      --   Lottable10,        
      --   Lottable11,        
      --   Lottable12,        
      --   Lottable13,        
      --   Lottable14,        
      --   Lottable15,        
      --   Notes,        
      --   Notes2,        
      --   Channel,        
      --   ROW_NO = 0 INTO #temp_OrderDetail        
      --FROM OrderDetail(NOLOCK)        
      --WHERE 1 = 2        
        
        
      --/********* Get Orders Table data  *********/                          
      IF (@n_continue = 1 OR @n_continue = 2)        
      BEGIN        
         INSERT INTO #Temp_FinalOrders (OrderKey, ExternOrderKey, M_Company, ShipperKey, SplitNum)        
            SELECT        
               O.OrderKey,        
               O.ExternOrderKey,        
               O.M_Company,        
               O.ShipperKey,    
               COUNT(DISTINCT ISNULL(c.UDF02,'')) AS SplitNum        
            FROM ORDERS O WITH (NOLOCK)        
            INNER JOIN ORDERDETAIL OD WITH (NOLOCK)        
               ON OD.OrderKey = O.OrderKey        
            INNER JOIN SKU s WITH (NOLOCK)        
               ON s.StorerKey = OD.StorerKey        
               AND s.Sku = OD.Sku        
            LEFT JOIN CODELKUP C WITH (NOLOCK)   --Change to left join make sure all detail will split      
               ON C.Storerkey = s.StorerKey        
               AND C.LISTNAME = 'SKUGROUP'        
               AND c.Code = s.SUSR3        
            WHERE O.StorerKey = @c_StorerKey        
            AND O.Status = '0'        
            AND O.SOStatus = 'PENDSPL'        
            AND (O.ECOM_PRESALE_FLAG = '' OR O.ECOM_PRESALE_FLAG IS NULL)        
            GROUP BY O.OrderKey,        
                     O.ExternOrderKey,        
                     O.M_Company,    
                     O.ShipperKey    
        
         IF (@b_debug = 1)        
         BEGIN        
            SELECT        
               COUNT(1) AS 'Number of Record in #Temp_Orders'        
            FROM #Temp_FinalOrders        
        
            SELECT * FROM #Temp_FinalOrders        
         END        
        
         IF NOT EXISTS (SELECT 1 FROM #Temp_FinalOrders)        
         BEGIN        
            SET @n_continue = 3        
            --SET @c_errmsg = N'No orders in #Temp_FinalOrders'    
    
            IF (@b_debug = 1)        
            BEGIN        
               SELECT        
                  'No orders in #Temp_FinalOrders' AS [debug_#Temp_FinalOrders]        
            END        
        
            --GOTO EXIT_SP         
         END        
      END        
        
      /****************** Update  for Non-Combine Orders **********************/        
      IF (@n_continue = 1 OR @n_continue = 2)        
      BEGIN          
         DECLARE CUR_READ_NonSplitOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
         SELECT O.[OrderKey]        
         FROM #Temp_FinalOrders O WITH (NOLOCK)        
         WHERE [SplitNum] <= 1 OR NOT EXISTS (    
                             SELECT 1 FROM [dbo].[CODELKUP] C WITH (NOLOCK)     
         WHERE C.LISTNAME='SPLORDSHPK'     
         AND C.Storerkey=@c_StorerKey AND c.Code=O.ShipperKey)        
        
         OPEN CUR_READ_NonSplitOrders        
         FETCH NEXT FROM CUR_READ_NonSplitOrders INTO @c_OrderKey        
        
         WHILE (@@FETCH_STATUS <> -1)        
         BEGIN        
            UPDATE [dbo].[ORDERS] WITH (ROWLOCK)        
            SET [SOStatus] = '0',        
                [Issued] = 'N',        
                TrafficCop = NULL,        
                EditDate = GETDATE(),        
                EditWho = SUSER_SNAME()        
            WHERE [OrderKey] = @c_OrderKey        
            AND [Status] <> 'CANC'        
            AND [SOStatus] <> ' PENDCANC'        
        
            FETCH NEXT FROM CUR_READ_NonSplitOrders INTO @c_OrderKey        
         END        
         CLOSE CUR_READ_NonSplitOrders        
         DEALLOCATE CUR_READ_NonSplitOrders              
      END        
        
      WHILE @@TRANCOUNT > 0         
         COMMIT TRAN        
        
      SET @c_OrderKey = ''        
      /****************** Update/Locate/Combine  for Combinable Orders **********************/        
      IF (@n_continue = 1 OR @n_continue = 2)        
      BEGIN        
         IF (@b_debug = 1)        
         BEGIN        
            SELECT        
               'Updating split orders'        
         END        
        
         TRUNCATE TABLE #temp_SplitOrderLines        
        
         IF @b_debug = 1        
         BEGIN        
            SELECT        
               OD.OrderKey,        
               OD.OrderLineNumber,        
               FO.ExternOrderKey,        
               FO.M_Company,        
               ISNULL(C.UDF02,'') AS SplitType,        
               ROW_NUMBER() OVER (PARTITION BY OD.OrderKey, ISNULL(C.UDF02,'') ORDER BY OD.OrderLineNumber)        
            FROM #Temp_FinalOrders FO        
            INNER JOIN ORDERDETAIL OD WITH (NOLOCK)        
               ON OD.OrderKey = FO.OrderKey        
            INNER JOIN SKU s WITH (NOLOCK)        
               ON s.StorerKey = OD.StorerKey        
               AND s.Sku = OD.Sku        
            LEFT JOIN CODELKUP C WITH (NOLOCK)  --Change to left join make sure all detail will split      
               ON C.Storerkey = s.StorerKey        
               AND C.LISTNAME = 'SKUGROUP'        
               AND c.Code = s.SUSR3        
            WHERE FO.[SplitNum] > 1 AND EXISTS (    
                                SELECT 1 FROM [dbo].[CODELKUP] C WITH (NOLOCK)     
           WHERE C.LISTNAME='SPLORDSHPK'     
           AND C.Storerkey=@c_StorerKey AND C.Code=FO.ShipperKey)            
         END        
        
         INSERT INTO #temp_SplitOrderLines (OrderKey, OrderLineNumber, ExternOrderKey, M_Company, SplitType, Row_No)        
            SELECT        
               OD.OrderKey,        
               OD.OrderLineNumber,        
               FO.ExternOrderKey,        
               FO.M_Company,        
               ISNULL(C.UDF02,''),        
               ROW_NUMBER() OVER (PARTITION BY OD.OrderKey, ISNULL(C.UDF02,'') ORDER BY OD.OrderLineNumber)        
            FROM #Temp_FinalOrders FO        
            INNER JOIN ORDERDETAIL OD WITH (NOLOCK)        
               ON OD.OrderKey = FO.OrderKey        
            INNER JOIN SKU s WITH (NOLOCK)        
               ON s.StorerKey = OD.StorerKey        
               AND s.Sku = OD.Sku        
            LEFT JOIN CODELKUP C WITH (NOLOCK)  --Change to left join make sure all detail will split      
               ON C.Storerkey = s.StorerKey        
               AND C.LISTNAME = 'SKUGROUP'        
               AND c.Code = s.SUSR3        
            WHERE FO.[SplitNum] > 1 AND EXISTS (    
                                SELECT 1 FROM [dbo].[CODELKUP] C WITH (NOLOCK)     
           WHERE C.LISTNAME='SPLORDSHPK'     
           AND C.Storerkey=@c_StorerKey AND C.Code=FO.ShipperKey)            
        
         IF @b_debug = 1        
         BEGIN        
            SELECT * FROM #temp_SplitOrderLines        
         END        
        
         DECLARE CUR_READ_SplitOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
         SELECT        
            A.OrderKey,        
            A.[SplitNum]        
         FROM #Temp_FinalOrders A        
         WHERE A.[SplitNum] > 1 AND EXISTS (    
                                SELECT 1 FROM [dbo].[CODELKUP] C WITH (NOLOCK)     
           WHERE C.LISTNAME='SPLORDSHPK'     
           AND C.Storerkey=@c_StorerKey AND C.Code=A.ShipperKey)      
        
         OPEN CUR_READ_SplitOrders        
         FETCH NEXT FROM CUR_READ_SplitOrders INTO @c_OrderKey, @n_SplitNum        
        
         WHILE (@@FETCH_STATUS <> -1)        
         BEGIN -- 1st cursor               
        
            DECLARE CUR_READ_SplitOrderLine CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT DISTINCT        
               SplitType        
            FROM #temp_SplitOrderLines        
            WHERE OrderKey = @c_OrderKey        
        
            OPEN CUR_READ_SplitOrderLine        
            FETCH NEXT FROM CUR_READ_SplitOrderLine INTO @c_SplitType        
            WHILE (@@FETCH_STATUS <> -1)        
            BEGIN        
               IF (@n_continue = 1 OR @n_continue = 2)        
               BEGIN        
                  SELECT @c_NewOrderkey = ''        
                  SELECT @b_success = 1        
                  EXECUTE nspg_getkey 'Order',        
                                       10,        
                                       @c_NewOrderkey OUTPUT,        
                                       @b_success OUTPUT,        
                                       @n_err OUTPUT,        
                                       @c_errmsg OUTPUT        
               END        
        
               BEGIN TRAN        
        
               IF NOT (@b_success = 1)        
               BEGIN        
                  SELECT        
                     @n_continue = 3        
                  SET @c_errmsg = N'FAIL MERGING. Unable to acquired new orderkey.'        
                  GOTO EXIT_SP        
               END        
        
               TRUNCATE TABLE #temp_OrderDetail        
               IF @b_debug = 1        
               BEGIN        
                  SELECT        
                     @c_OrderKey AS OriginalOrderKey,        
                     @n_SplitNum AS SplitNum,        
                     @c_SplitType AS SplitType        
        
                  SELECT        
                     @c_NewOrderkey,        
                     0,        
                     @c_NewOrderkey,        
                     T1.[ExternLineNo],        
                     T1.[Sku],        
                     T1.[StorerKey],        
                     T1.[ManufacturerSku],        
                     T1.[RetailSku],        
                     T1.[AltSku],        
                     T1.[OriginalQty],        
                     T1.[OpenQty],        
                     0,        
                     0,        
                     [QtyPreAllocated],        
                     [QtyAllocated],        
                     [QtyPicked],        
                     [UOM],        
                     [PackKey],        
                     [PickCode],        
                     [CartonGroup],        
                     [Lot],        
                     [ID],        
                     [Facility],        
                     '0',        
                     T1.[UnitPrice],        
                     T1.[Tax01],        
                     T1.[Tax02],        
                     T1.[ExtendedPrice],        
                     T1.[UpdateSource],        
                     T1.[Lottable01],        
                     T1.[Lottable02],        
                     T1.[Lottable03],        
                     T1.[Lottable04],        
                     T1.[Lottable05],        
                     AddDate,        
                     AddWho,        
                     T1.[FreeGoodQty],        
                     T1.[GrossWeight],        
                     T1.[Capacity],        
                     T1.[QtyToProcess],        
                     T1.[MinShelfLife],        
                     T1.[UserDefine01],        
                     T1.[UserDefine02],        
                     T1.[UserDefine03],        
                     T1.[UserDefine04],        
                     T1.Orderkey,        
                     CONVERT(nvarchar(18), T2.Externorderkey),        
                     '',        
                     T1.UserDefine08,        
                     '',        
                     T1.[POkey],        
                     T1.[ExternPOKey],        
                     T1.[UserDefine10],        
                     T1.EnteredQTY,        
                     '',        -- Split Order needn't value in Conso* column 
                     '',        
                     '',        
                     T1.[Lottable06],        
                     T1.[Lottable07],        
                     T1.[Lottable08],        
                     T1.[Lottable09],        
                     T1.[Lottable10],        
                     T1.[Lottable11],        
                     T1.[Lottable12],        
                     T1.[Lottable13],        
                     T1.[Lottable14],        
                     T1.[Lottable15],        
                     T2.M_Company,        
                     T1.[Notes2],        
                     T1.[Channel] --tlting                          
                     ,        
                     T2.[Row_No]        
                  FROM ORDERDETAIL T1 WITH (NOLOCK)        
                  JOIN #temp_SplitOrderLines T2        
                     ON T2.OrderKey = T1.OrderKey        
                     AND T2.OrderLineNumber = T1.OrderLineNumber        
                  WHERE T2.OrderKey = @c_OrderKey        
                  AND T2.SplitType = @c_SplitType        
                  ORDER BY T2.[Row_No]        
               END -- IF @b_debug = 1        
        
               IF EXISTS (SELECT 1 FROM ORDERS(NOLOCK)        
                          WHERE ORDERS.Orderkey = @c_OrderKey         
                          AND Orders.status <> 'CANC'        
                          AND Orders.SOStatus <> 'PENDCANC')        
               BEGIN        
                  INSERT INTO #temp_OrderDetail ([OrderKey], [OrderLineNumber], [ExternOrderKey], [ExternLineNo]        
                  , [Sku], [StorerKey], [ManufacturerSku], [RetailSku], [AltSku], [OriginalQty], [OpenQty], [ShippedQty], [AdjustedQty]        
                  , [QtyPreAllocated], [QtyAllocated], [QtyPicked], [UOM], [PackKey], [PickCode], [CartonGroup], [Lot], [ID], [Facility]        
                  , [Status], [UnitPrice], [Tax01], [Tax02], [ExtendedPrice], [UpdateSource], [Lottable01], [Lottable02], [Lottable03]        
                  , [Lottable04], [Lottable05], AddDate, AddWho, [FreeGoodQty], [GrossWeight], [Capacity], [QtyToProcess], [MinShelfLife]        
                  , [UserDefine01], [UserDefine02], [UserDefine03], [UserDefine04], [UserDefine05], [UserDefine06], [UserDefine07]        
                  , UserDefine08, UserDefine09, [POkey], [ExternPOKey], [UserDefine10], EnteredQTY, [ConsoOrderKey]        
                  , [ExternConsoOrderKey], [ConsoOrderLineNo], [Lottable06], [Lottable07], [Lottable08], [Lottable09], [Lottable10]        
                  , [Lottable11], [Lottable12], [Lottable13], [Lottable14], [Lottable15], [Notes], [Notes2], [Channel], ROW_NO)        
                     SELECT        
                        @c_NewOrderkey,        
                        0,        
                        @c_NewOrderkey,        
                        T1.[ExternLineNo],        
                        T1.[Sku],        
                        T1.[StorerKey],        
                        T1.[ManufacturerSku],        
                        T1.[RetailSku],        
                        T1.[AltSku],        
                        T1.[OriginalQty],        
                        T1.[OpenQty],        
                        0,        
                        0,        
                        [QtyPreAllocated],        
                        [QtyAllocated],        
                        [QtyPicked],        
                        [UOM],        
                        [PackKey],        
                        [PickCode],        
                        [CartonGroup],        
                        [Lot],        
                        [ID],        
                        [Facility],        
                        '0',        
                        T1.[UnitPrice],        
                        T1.[Tax01],        
                        T1.[Tax02],        
                        T1.[ExtendedPrice],        
                        T1.[UpdateSource],        
                        T1.[Lottable01],        
                        T1.[Lottable02],        
                        T1.[Lottable03],        
                        T1.[Lottable04],        
                        T1.[Lottable05],        
                        AddDate,        
                        AddWho,        
                        T1.[FreeGoodQty],        
                        T1.[GrossWeight],        
                        T1.[Capacity],        
                        T1.[QtyToProcess],        
                        T1.[MinShelfLife],        
                        T1.[UserDefine01],        
                        T1.[UserDefine02],        
                        T1.[UserDefine03],        
                        T1.[UserDefine04],        
                        T1.Orderkey,        
                        CONVERT(nvarchar(18), T2.Externorderkey),        
                        '',        
                        T1.UserDefine08,        
                        '',        
                        T1.[POkey],        
                        T1.[ExternPOKey],        
                        T1.[UserDefine10],        
                        T1.EnteredQTY,        
                        '',        -- Split Order needn't value in Conso* column
                        '',        
                        '',        
                        T1.[Lottable06],        
                        T1.[Lottable07],        
                        T1.[Lottable08],        
                        T1.[Lottable09],        
                        T1.[Lottable10],        
                        T1.[Lottable11],        
                        T1.[Lottable12],        
                        T1.[Lottable13],        
                        T1.[Lottable14],        
                        T1.[Lottable15],        
                        T2.M_Company,        
                        T1.[Notes2],        
                        T1.[Channel] --tlting                          
                        ,        
                        T2.[Row_No]        
                     FROM ORDERDETAIL T1 WITH (NOLOCK)        
                     JOIN #temp_SplitOrderLines T2 ON T2.OrderKey = T1.OrderKey        
                                            AND T2.OrderLineNumber = T1.OrderLineNumber        
                     WHERE T2.OrderKey = @c_OrderKey        
                     AND T2.SplitType = @c_SplitType         
                     ORDER BY T2.[Row_No]        
                  END         
        
                  IF @b_debug = 1        
                  BEGIN        
                     SELECT * FROM #temp_OrderDetail        
                  END        
        
                  IF NOT EXISTS (SELECT 1 FROM #temp_OrderDetail)        
                  BEGIN        
                     ROLLBACK TRAN        
        
                     -- SET @n_continue = 3        
                     SET @c_errmsg = N'FAIL SPLITTING. Unable to INSERT split orderdetail into @temp_OrderDetail.'        
                     GOTO FETCH_NEXT_ORDER        
                  END        
        
        
                  DECLARE CUR_READ_Orderkey_SplitOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
                  SELECT        
                     OrderLineNumber,         
                     Row_No        
                  FROM #temp_SplitOrderLines        
                  WHERE OrderKey = @c_OrderKey        
                  AND SplitType = @c_SplitType        
        
                  OPEN CUR_READ_Orderkey_SplitOrders        
                  FETCH NEXT FROM CUR_READ_Orderkey_SplitOrders INTO @c_OrderLineNo, @n_Row_No        
        
                  WHILE (@@FETCH_STATUS <> -1)        
                  BEGIN -- 2nd cursor (orderkey)                          
        
                     -- if Orders not Cancel                        
                     IF EXISTS (SELECT 1        
                        FROM Orders(NOLOCK)        
                        WHERE [OrderKey] = @c_OrderKey        
                        AND Status = '0'        
                        AND SOStatus <> 'CANC'        
                        AND SOStatus <> 'PENDCANC')        
                     BEGIN        
                        UPDATE [dbo].[ORDERS] WITH (ROWLOCK)        
                        SET [SOStatus] = '0',        
                          [OrderGroup] = 'ORI_ORDER',        
                            ContainerQty = @n_SplitNum,  --for courier api to get multi trackingno                                    
                            Issued = 'N',        
                            TrafficCop = NULL,        
                            EditDate = GETDATE(),        
                            EditWho = SUSER_SNAME()        
                        WHERE [OrderKey] = @c_OrderKey        
        
                        UPDATE dbo.Orderdetail WITH (ROWLOCK)        
                        SET ConsoOrderKey = @c_NewOrderkey,        
                            ConsoOrderLineNo = RIGHT('00000' + CAST(@n_Row_No AS varchar), 5),        
                            TrafficCop = NULL,        
                            EditDate = GETDATE(),        
                            EditWho = SUSER_SNAME()        
                        FROM dbo.Orderdetail        
                        WHERE Orderdetail.Orderkey = @c_OrderKey        
                        AND OrderLineNumber = @c_OrderLineNo        
                        AND EXISTS (SELECT 1        
                                    FROM Orders(NOLOCK)        
                                    WHERE Orders.orderkey = Orderdetail.orderkey        
                                    AND Orders.OrderGroup = 'ORI_ORDER')        
        
                     END -- if exists                                   
                     FETCH NEXT FROM CUR_READ_Orderkey_SplitOrders INTO @c_OrderLineNo, @n_Row_No        
                  END -- 2nd cursor (orderkey)                          
                  CLOSE CUR_READ_Orderkey_SplitOrders        
                  DEALLOCATE CUR_READ_Orderkey_SplitOrders        
        
        
                  SET @n_Notes2 = ''        
                  SET @n_Notes2 = (SELECT DISTINCT        
                     RTRIM(L.PickZone) + ''        
                  FROM #temp_OrderDetail OD        
                  INNER JOIN dbo.SKUxLOC SL WITH (NOLOCK)        
                     ON SL.StorerKey = OD.StorerKey        
                     AND SL.Sku = OD.Sku        
                     INNER JOIN dbo.LOC L WITH (NOLOCK)        
                        ON L.Loc = SL.Loc        
                  WHERE SL.LocationType = 'PICK'        
                  GROUP BY L.PickZone        
                  ORDER BY 1        
                  FOR xml PATH (''))        
                  SET @n_Notes2 = ISNULL(@n_Notes2, '')        
        
                  IF @b_debug = 1        
                  BEGIN        
                     SELECT        
                        @c_NewOrderkey AS 'SplitOrderKey',        
                        @n_Notes2 AS 'Notes2'        
                  END        
        
                  INSERT INTO ORDERS ([OrderKey], [StorerKey], [ExternOrderKey], [OrderDate], [DeliveryDate], [Priority],        
                  [ConsigneeKey], [C_Contact1], [C_Contact2], [C_Company], [C_Address1], [C_Address2], [C_Address3], [C_Address4],        
                  [C_City], [C_State], [C_Zip], C_Country, C_ISOCntryCode, [C_Phone1], [C_Phone2], C_Fax1, C_Fax2, C_vat, [BuyerPO],        
                  BillToKey, B_contact1, B_Contact2, B_Company, B_Address1, B_Address2, B_Address3, B_Address4, B_City, B_State, B_Zip,        
                  B_Country, B_ISOCntryCode, B_Phone1, B_Phone2, B_Fax1, B_Fax2, B_Vat, IncoTerm,        
                  [PmtTerm], [OpenQty], [Status], DischargePlace, DeliveryPlace, IntermodalVehicle, CountryOfOrigin, CountryDestination,        
                  UpdateSource, [Type], [OrderGroup], [Stop], Notes, AddDate, AddWho, ContainerType, ContainerQty, [SOSTATUS], [POKey],        
                  [InvoiceAmount], [Salesman], [Notes2], SectionKey, [Facility], LabelPrice, [UserDefine01], [UserDefine03], [UserDefine04], [UserDefine05],        
                  [UserDefine08], Issued, DeliveryNote, [SpecialHandling], [RoutingTool], M_Contact1, M_Contact2, [M_Company],        
                  M_Address1, M_Address2, M_Address3, M_Address4, M_City, M_State, M_Zip, M_Country, M_ISOCntryCode, M_Phone1, M_Phone2, M_Fax1,        
                  M_Fax2, M_vat, [ShipperKey], [DocType], [TrackingNo], [ECOM_PRESALE_FLAG], [ECOM_SINGLE_Flag])        
                     SELECT        
                        @c_NewOrderkey,        
                        Storerkey,        
                        @c_NewOrderkey,        
                        OrderDate,        
                        DeliveryDate,        
                        [Priority],        
                        ConsigneeKey,        
                        C_contact1,        
                        C_Contact2,        
                        C_Company,        
                        C_Address1,        
                        C_Address2,        
                        C_Address3,        
                        C_Address4,        
                        C_City,        
                        C_State,        
                        C_Zip,        
                        C_Country,        
                        C_ISOCntryCode,        
                        C_Phone1,        
                        C_Phone2,        
                        C_Fax1,        
                        C_Fax2,        
                        C_vat,        
                        BuyerPO,        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',       
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        PmtTerm,        
                        0,        
                        '0',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        [Type],        
                        'SPLIT_ORD',        
                        [STOP],        
                        '',        
                        AddDate,        
                        AddWho,        
                        '',        
                        0,        
                        0,        
                        @c_OrderKey, --set original Orderkey into pokey                            
                        [InvoiceAmount],        
                        Salesman,        
                        @n_Notes2,        
                        '',        
                        Facility,        
                        '',        
                        [UserDefine01],        
                        Userdefine03,        
                        UserDefine04,        
                        [UserDefine05],        
                        UserDefine08,        
                        'N',        
                        '',        
                        SpecialHandling,        
                        RoutingTool,        
                        '',        
                        '',        
                        [M_Company],        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                        '',        
                     '',        
                        ShipperKey,        
                        DocType,        
                        [TrackingNo],        
                        [ECOM_PRESALE_FLAG],        
                        [ECOM_SINGLE_Flag]        
                     FROM ORDERS WITH (NOLOCK)        
                     WHERE ORDERKEY = @c_OrderKey        
                     AND Orders.SOStatus = '0'        
        
        
                  IF EXISTS (SELECT 1 FROM #temp_OrderDetail)        
                     AND EXISTS (SELECT 1 FROM ORDERS(NOLOCK)        
                     WHERE orderkey = @c_NewOrderkey        
                     AND status = '0'        
                     AND SOSTATUS = '0')        
                  BEGIN        
                     --INSERT INTO dbo.ORDERDETAIL                          
                     INSERT INTO dbo.ORDERDETAIL ([OrderKey], [OrderLineNumber], [ExternOrderKey], [ExternLineNo]        
                     , [Sku], [StorerKey], [ManufacturerSku], [RetailSku], [AltSku], [OriginalQty], [OpenQty], [ShippedQty], [AdjustedQty]        
                     , [QtyPreAllocated], [QtyAllocated], [QtyPicked], [UOM], [PackKey], [PickCode], [CartonGroup], [Lot], [ID], [Facility]        
                     , [Status], [UnitPrice], [Tax01], [Tax02], [ExtendedPrice], [UpdateSource], [Lottable01], [Lottable02], [Lottable03]        
                     , [Lottable04], [Lottable05], AddDate, AddWho, [FreeGoodQty], [GrossWeight], [Capacity], [QtyToProcess], [MinShelfLife]        
                     , [UserDefine01], [UserDefine02], [UserDefine03], [UserDefine04], [UserDefine05], [UserDefine06], [UserDefine07]        
                     , UserDefine08, UserDefine09, [POkey], [ExternPOKey], [UserDefine10], EnteredQTY, [ConsoOrderKey]        
                     , [ExternConsoOrderKey], [ConsoOrderLineNo], [Lottable06], [Lottable07], [Lottable08], [Lottable09], [Lottable10]        
                     , [Lottable11], [Lottable12], [Lottable13], [Lottable14], [Lottable15], [Notes], [Notes2], [Channel])        
        
                        SELECT        
                           [OrderKey],        
                           RIGHT('00000' + CAST(ROW_NO AS varchar), 5),        
                           [ExternOrderKey],        
                           [ExternLineNo],        
                           [Sku],        
                           [StorerKey],        
                           [ManufacturerSku],        
                           [RetailSku],        
                           [AltSku],        
                           [OriginalQty],        
                           [OpenQty],        
                           [ShippedQty],        
                           [AdjustedQty],        
                           [QtyPreAllocated],        
                           [QtyAllocated],        
                           [QtyPicked],        
                           [UOM],        
                           [PackKey],        
                           [PickCode],        
                           [CartonGroup],        
                           [Lot],        
                           [ID],        
                           [Facility],        
                           [Status],        
                           [UnitPrice],        
                           [Tax01],        
                           [Tax02],        
                           [ExtendedPrice],        
                           [UpdateSource],        
                           [Lottable01],        
                           [Lottable02],        
                           [Lottable03],        
                           [Lottable04],        
                           [Lottable05],        
                           AddDate,        
                           AddWho,        
                           [FreeGoodQty],        
                           [GrossWeight],        
                           [Capacity],        
                           [QtyToProcess],        
                           [MinShelfLife],        
                           [UserDefine01],        
                           [UserDefine02],        
                           [UserDefine03],        
                           [UserDefine04],        
                           [UserDefine05],        
                           [UserDefine06],        
                           [UserDefine07],        
                           UserDefine08,        
                           UserDefine09,        
                           [POkey],        
                           [ExternPOKey],        
                           [UserDefine10],        
                           EnteredQTY,        
                           [ConsoOrderKey],        
                           [ExternConsoOrderKey],        
                           [ConsoOrderLineNo],        
                           [Lottable06],        
                           [Lottable07],        
                           [Lottable08],        
                           [Lottable09],        
                           [Lottable10],        
                           [Lottable11],        
                           [Lottable12],        
                           [Lottable13],        
                           [Lottable14],        
                           [Lottable15],        
                           [Notes],        
                           [Notes2],        
                           [Channel]        
                        FROM #temp_OrderDetail        
                        ORDER BY ROW_NO        
        
                     IF @@ROWCOUNT = 0        
                        OR @@ERROR <> 0        
                     BEGIN        
                        ROLLBACK TRAN        
                        SET @n_continue = 3        
                        SET @c_errmsg = N'FAIL MERGING, Unable to insert parent orders orderdetail.'        
                        GOTO EXIT_SP        
                     END        
                  END        
        
               COMMIT TRAN        
        
               FETCH NEXT FROM CUR_READ_SplitOrderLine INTO @c_SplitType        
            END        
        
            CLOSE CUR_READ_SplitOrderLine        
            DEALLOCATE CUR_READ_SplitOrderLine        
        
            FETCH_NEXT_ORDER:        
            FETCH NEXT FROM CUR_READ_SplitOrders INTO @c_OrderKey, @n_SplitNum        
         END -- 1st cursor (Row_no)                          
         CLOSE CUR_READ_SplitOrders        
         DEALLOCATE CUR_READ_SplitOrders        
        
      EXIT_SP:        
        
         IF @n_Continue = 3  -- Error Occured - Process And Return                                
         BEGIN        
            SELECT        
               @b_Success = 0        
            IF @@TRANCOUNT = 1        
               AND @@TRANCOUNT > @n_StartTCnt        
            BEGIN        
               ROLLBACK TRAN        
            END        
            ELSE        
            BEGIN        
               WHILE @@TRANCOUNT > @n_StartTCnt        
               BEGIN        
                  COMMIT TRAN        
               END        
            END        
            EXECUTE nsp_logerror @n_Err,        
                                 @c_ErrMsg,        
                                 'isp_OrdersSplitting'        
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012                                
            RETURN        
         END        
         ELSE        
         BEGIN        
            SELECT        
               @b_Success = 1        
            WHILE @@TRANCOUNT > @n_StartTCnt        
            BEGIN        
               COMMIT TRAN        
            END        
            RETURN        
         END        
      END        
        
        
   END

GO