SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*-------------------------------------------------------------------------------------------------------*/                        
/* Stored Procedure: isp_RCM_WAVE_OrdersMerging                                                          */                              
/* Creation Date: 04-Aug-2023                                                                            */                                
/* Copyright: Maersk                                                                                     */                                
/* Written by:                                                                                           */                                
/*                                                                                                       */                                
/* Purpose: WMS-23621 - Combine Order data when there are duplicate values base on codelkup columns      */                                
/*                                                                                                       */                                
/* Called By: Wave                                                                                       */                                 
/*                                                                                                       */                                
/* Parameters:                                                                                           */                                
/*                                                                                                       */                                
/* PVCS Version: 1.0                                                                                     */                                
/*                                                                                                       */                                
/* Version: 5.4                                                                                          */                                
/*                                                                                                       */                                
/* Data Modifications:                                                                                   */                                
/*                                                                                                       */                                
/* Updates:                                                                                              */                                
/* Date         Author    Ver. Purposes                                                                  */                         
/* 04-Aug-2023  Josh      1.0  Initial version                                                           */                          
/*-------------------------------------------------------------------------------------------------------*/                        

CREATE   PROCEDURE [dbo].[isp_RCM_WAVE_OrdersMerging]                     
(                                           
   @c_WaveKey NVARCHAR(10),  
   @b_Success  INT OUTPUT,     
   @n_err      INT OUTPUT, 
   @c_errmsg NVARCHAR(128) = '' OUTPUT,
   @c_code     NVARCHAR(30)=''    
)                        
AS                        
SET NOCOUNT ON                            
SET ANSI_NULLS OFF                            
SET QUOTED_IDENTIFIER OFF                            
SET CONCAT_NULL_YIELDS_NULL OFF                         
BEGIN                                                
   DECLARE @c_StorerKey NVARCHAR(15)
          ,@c_SValue       NVARCHAR(1)      
          ,@c_Option5      NVARCHAR(4000)
   	      ,@c_Option1      NVARCHAR(50)  
          ,@n_continue     INT                        
          ,@n_columnsTotal INT                        
          ,@c_ExecSttmt    NVARCHAR(max)                        
          ,@c_ExecArgSttmt NVARCHAR(max)                        
          ,@c_AllFromColumns   NVARCHAR(4000)                        
          ,@c_AllToColumns NVARCHAR(4000)  
   	      ,@c_FuncColumns  NVARCHAR(4000)  
          ,@c_WhereColumn  NVARCHAR(4000)                        
          ,@c_ColumnName   NVARCHAR(45)                        
          ,@c_ColumnType   NVARCHAR(30)   
          ,@c_ColumnFuncStart   NVARCHAR(60)   
          ,@c_ColumnFuncEnd     NVARCHAR(60)   
          ,@c_OrderKey     NVARCHAR(10)                        
          ,@c_ExternOrderKey NVARCHAR(50)  --tlting_ext                  
          ,@n_Row_No       INT                                             
          ,@c_GetOrderKeys NVARCHAR(4000)                        
          ,@c_GetExternOrderList NVARCHAR(4000)                        
          ,@c_NewOrderkey  NVARCHAR(10)                                              
          ,@n_rowcount     INT                                             
          ,@n_lineNo       INT                        
          ,@c_OD_OrderKey       NVARCHAR(10)                        
          ,@c_OD_OrderLine      NVARCHAR(5)                        
          ,@c_OD_MCompany       NVARCHAR(4000)                        
          ,@c_OD_ExOrderKey     NVARCHAR(50)                                                               
          ,@n_TotOpenQty   INT                                
          ,@n_StartTCnt        INT                        
          ,@n_Notes2            NVARCHAR(4000)              
   	      ,@c_Wavedetailkey     NVARCHAR(10)
   	      ,@b_debug INT = 0 --(1 for on, 0 for off, default 0)                                                                      
                           
   /********** Initial parameter values **************/                          
   SELECT @c_SValue        = NULL  
   SELECT @c_Option1       = ''
   SELECT @c_Option5       = ''
   SELECT @n_columnsTotal  = 0                        
   SELECT @c_ExecSttmt     = ''                        
   SELECT @c_ExecArgSttmt  = ''                        
   SELECT @c_AllFromColumns    = ''                        
   SELECT @c_AllToColumns  = ''    
   SELECT @c_FuncColumns   = ''    
   SELECT @c_WhereColumn   = ''                        
   SELECT @n_continue = 1, @b_success = 0, @n_err = '' , @n_rowcount = 0                        
   SET @n_StartTCnt = @@ROWCOUNT                        
                           
   /********* Create temp table *********/                  
   IF @n_continue IN(1,2)
   BEGIN                   
      IF ISNULL(OBJECT_ID('tempdb..#Temp_FinalOrders'), '') <> ''                        
      BEGIN                        
         DROP TABLE #Temp_FinalOrders                        
      END                        
                              
      CREATE TABLE #Temp_FinalOrders                        
      (                        
         OrderKey       NVARCHAR(10)                        
        ,ExternOrderKey NVARCHAR(50)  --tlting_ext                               
        ,Row_no         INT                              
      )  
      CREATE INDEX TempORDIndex ON #Temp_FinalOrders (OrderKey)     
                              
      DECLARE @temp_CodelkupTable TABLE                   
      (                        
         Code  NVARCHAR(30)
        ,Long  NVARCHAR(45)
        ,Code2 NVARCHAR(30)
        ,UDF01 NVARCHAR(60)
        ,UDF02 NVARCHAR(60)
      )                        
      
      IF ISNULL(OBJECT_ID('tempdb..#temp_OrderDetail'),'') <> ''                        
      BEGIN                        
         DROP TABLE #temp_OrderDetail                        
      END                   
                       
      SELECT OrderKey, OrderLineNumber, ExternOrderKey, ExternLineNo, StorerKey, Sku, ManufacturerSku, RetailSku, AltSku, OriginalQty, OpenQty,                
             ShippedQty, AdjustedQty, QtyPreAllocated, QtyAllocated, QtyPicked, UOM, PackKey, PickCode, CartonGroup, Lot, ID, Facility, [Status], UnitPrice,                
             Tax01, Tax02, ExtendedPrice, UpdateSource, Lottable01,Lottable02, Lottable03, Lottable04, Lottable05, AddDate, AddWho, FreeGoodQty,                
             GrossWeight, Capacity, QtyToProcess, MinShelfLife, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine06,                
             UserDefine07, UserDefine08, UserDefine09, POkey, ExternPOKey, UserDefine10, EnteredQTY, ConsoOrderKey, ExternConsoOrderKey, ConsoOrderLineNo,                
             Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, Notes, Notes2, Channel, ROW_NO = 0                
      INTO #temp_OrderDetail FROM OrderDetail (NOLOCK)                
      WHERE 1=2       
   END                 
                                              
   /********* Wave checking *********/            
   IF @n_continue IN(1,2)
   BEGIN            
      IF NOT EXISTS(SELECT TOP 1 1 FROM WAVEDETAIL WITH (NOLOCK) WHERE WaveKey=@c_WaveKey)                        
      BEGIN             
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
              , @n_err = 83010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                            + ': Invalid WaveKey: ''' + @c_WaveKey + '''. (isp_RCM_WAVE_OrdersMerging)' + ' ( ' + ' SQLSvr MESSAGE='
                               + RTRIM(@c_errmsg) + ' ) '

         IF (@b_debug = 1)                        
         BEGIN                        
            SELECT 'WaveKey = ' + @c_WaveKey                 
         END                        
      END                          
      
      IF EXISTS(SELECT TOP 1 1 FROM WAVEDETAIL WD WITH (NOLOCK) JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey WHERE WD.WaveKey=@c_WaveKey AND O.Status<>'CANC' AND O.Status>'0')                        
      BEGIN             
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
              , @n_err = 83020 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                            + ': Need WaveKey before Alloc: ''' + @c_WaveKey + '''. (isp_RCM_WAVE_OrdersMerging)' + ' ( ' + ' SQLSvr MESSAGE='
                               + RTRIM(@c_errmsg) + ' ) '

         IF (@b_debug = 1)                        
         BEGIN                        
            SELECT 'WaveKey = ' + @c_WaveKey                 
         END                        
      END        
      /********* StorerConfig checking *********/                           
      
      /********* Get Storerkey *********/                        
      SELECT TOP 1 @c_StorerKey = StorerKey 
      FROM WAVEDETAIL WITH (NOLOCK) JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = WAVEDETAIL.OrderKey
      WHERE WaveKey = @c_WaveKey      
                              
      SELECT @c_SValue = SVALUE
            ,@c_Option5 = OPTION5
      	  ,@c_Option1 = OPTION1
      FROM StorerConfig WITH (NOLOCK)                        
      WHERE ConfigKey = 'ORDCOMB2B' AND Storerkey = @c_StorerKey                        
                              
      IF (@c_SValue <> '1')                        
      BEGIN             
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
              , @n_err = 83030 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                            + ': FAIL MERGING. ConfigKey ''ORDCOMB2B'' for storerkey ''' + @c_StorerKey + ''' is Turn OFF. Refer StorerConfig Table. (isp_RCM_WAVE_OrdersMerging)' + ' ( ' + ' SQLSvr MESSAGE='
                               + RTRIM(@c_errmsg) + ' ) '

         IF (@b_debug = 1)                        
         BEGIN                        
            SELECT 'SVALUE = ' + @c_SValue, 'OPTION5 = ' + @c_Option5                        
         END                        
      END     
   END                   
                           
   /********* Acquiring Order table's Columns from Codelkup  *********/                                                  
   IF (@n_continue = 1  OR @n_continue = 2)                        
   BEGIN               
      INSERT INTO @temp_CodelkupTable ([Code], [long], [Code2], [UDF01], [UDF02])                         
      SELECT [Code],[Long],[code2],[UDF01],[UDF02]                         
      FROM CODELKUP WITH (NOLOCK) --(jay02)                        
      WHERE Listname = 'ORDCOMB2B' AND Storerkey = @c_StorerKey AND Short = '1' --(jay02)                        
      ORDER BY [Code] ASC                        
                           
      SELECT @n_columnsTotal = COUNT([Code]) FROM @temp_CodelkupTable                         
                           
      IF NOT EXISTS (SELECT 1 FROM @temp_CodelkupTable WHERE Code2 <> 'FUNC')    --if no normal column, raise error                     
      BEGIN                        
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
              , @n_err = 83040 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                            + ': FAIL MERGING. No columns acquire from ''CODELKUP'' table. (isp_RCM_WAVE_OrdersMerging)' + ' ( ' + ' SQLSvr MESSAGE='
                               + RTRIM(@c_errmsg) + ' ) '

      END                        
   END                        
                           
   --/********* Get Orders Table data  *********/                        
   IF (@n_continue = 1  OR @n_continue = 2)                        
   BEGIN                                                   
      SELECT @c_AllFromColumns = COALESCE(@c_AllFromColumns + ', ' , '' ) + CONVERT(NVARCHAR(25),RTRIM(LTRIM([Long])))                        
      FROM @temp_CodelkupTable WHERE Code2 <> 'FUNC'
                                 
      SELECT @c_AllFromColumns = Stuff(@c_AllFromColumns,1,1,'')      
      SELECT @c_AllToColumns = @c_AllFromColumns
                           
      DECLARE CUR_READ_Temp_Column CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                        
      SELECT [Long],[code2],[UDF01],[UDF02]                         
      FROM @temp_CodelkupTable                        
      ORDER BY [Code] ASC                        
                           
      OPEN CUR_READ_Temp_Column                          
      
      FETCH NEXT FROM CUR_READ_Temp_Column INTO @c_ColumnName, @c_ColumnType, @c_ColumnFuncStart, @c_ColumnFuncEnd
                           
      WHILE (@@FETCH_STATUS <> -1)                        
      BEGIN         
   	     IF @c_ColumnType = 'FUNC'
   	     BEGIN
   	        SET @c_AllFromColumns = @c_AllFromColumns + ',' + @c_ColumnFuncStart + @c_ColumnName + @c_ColumnFuncEnd + 'AS ' + @c_ColumnName
   		      SET @c_AllToColumns = @c_AllToColumns + ',' + @c_ColumnName                     
   	     END
   
         IF @c_WhereColumn = ''                        
         BEGIN                        
            SET @c_WhereColumn = 'ISNULL(RTRIM(LTRIM(#Temp_Orders.'+@c_ColumnName+')),'''')=ISNULL(RTRIM(LTRIM(#Temp_CombOrders.'+@c_ColumnName+')),'''') '                        
         END                        
         ELSE                        
         BEGIN                        
            SET @c_WhereColumn = @c_WhereColumn +'AND ISNULL(RTRIM(LTRIM(#Temp_Orders.'+@c_ColumnName+')),'''')=ISNULL(RTRIM(LTRIM(#Temp_CombOrders.'+@c_ColumnName+')),'''') '                        
         END   	     
         
         FETCH NEXT FROM CUR_READ_Temp_Column INTO @c_ColumnName, @c_ColumnType, @c_ColumnFuncStart, @c_ColumnFuncEnd
      END                        
      CLOSE CUR_READ_Temp_Column                        
      DEALLOCATE CUR_READ_Temp_Column          
                    
      --(row_no = 0 for non-combinable orders)                        
      SET @c_ExecSttmt = N'SELECT OrderKey, '+@c_AllFromColumns+',ExternOrderKey, [Row_No] = 0 '                         
                         +'INTO #Temp_Orders '                        
                         +'FROM ORDERS (NOLOCK) '
                         +'WHERE UserDefine09 = ''' + @c_WaveKey + ''' '
   					  +'AND StorerKey = @c_StorerKey '                        
                         +'AND Status = ''0'' AND SOStatus=''0'' '                        
                         +'AND DocType = ''N'' '              
                         +'AND ISNULL(OrderGroup,'''') <> ''CHILD_ORD'' '
   					  +'AND ISNULL(OrderGroup,'''') <> ''COM_ORDER'' '
   					  +@c_Option5
       
     -- TLTING01  
     IF CHARINDEX ( 'C_contact1' , @c_AllFromColumns ) > 0  
     BEGIN      
         SET @c_ExecSttmt = @c_ExecSttmt  + CHAR(13)  
                     + 'ALTER TABLE #Temp_Orders ALTER COLUMN C_contact1 NVARCHAR(100) COLLATE Chinese_PRC_CS_AS '+ CHAR(13)  
     END  
                   
      SET @c_ExecSttmt = @c_ExecSttmt                        
               +'SELECT '+@c_AllToColumns+ ', ROW_NUMBER() OVER (ORDER BY ' +@c_AllToColumns+') AS [Row_No]'                        
                         +'INTO #Temp_CombOrders '             --(search for combinable orders and set its row_no)                        
                         +'FROM #Temp_Orders '                        
                         +'GROUP BY '+@c_AllToColumns + ' '
                         +'HAVING COUNT(1) >1 '                        
      SET @c_ExecSttmt = @c_ExecSttmt                        
                         +'UPDATE #Temp_Orders '      --(update row_no <> 0 for combinable orders)                        
                         +'SET #Temp_Orders.[Row_No] = #Temp_CombOrders.[Row_No] '                        
                         +'FROM #Temp_Orders INNER JOIN #Temp_CombOrders  '                        
                     +'ON ( '+ @c_WhereColumn + ') '                        
      SET @c_ExecSttmt = @c_ExecSttmt                        
                         +'SELECT OrderKey, ExternOrderKey, [Row_No] from #Temp_Orders  ' --(jay03)                        
                         +'ORDER BY [Row_No] '                         
                           
      SET @c_ExecArgSttmt = N'@c_StorerKey  NVARCHAR(15)'                                             
                           
      IF(@b_debug = 1 )                        
      BEGIN                        
         SELECT @c_ExecSttmt AS 'TempOrd_Insert'                        
         SELECT @c_ExecArgSttmt AS 'TempOrd_Insert_Arg'                        
      END                        
                           
      INSERT INTO #Temp_FinalOrders                        
      EXECUTE sp_executesql @c_ExecSttmt, @c_ExecArgSttmt, @c_StorerKey                        
                           
      IF(@b_debug = 1 )                        
      BEGIN                        
   	     SELECT COUNT(1) AS 'Number of Record in #Temp_FinalOrders' FROM #Temp_FinalOrders                        
         SELECT * FROM #Temp_FinalOrders    
      END                        
                           
      IF NOT EXISTS (SELECT 1 FROM #Temp_FinalOrders)                        
      BEGIN                        
         SET @n_continue = 3                        
                           
     IF (@b_debug = 1)                        
         BEGIN                        
            SELECT 'No orders in #Temp_FinalOrders' AS [debug_#Temp_FinalOrders]                        
         END                        
      END                        
   END                        
                                               
   /****************** Update/Locate/Combine  for Combinable Orders **********************/                        
   IF (@n_continue = 1  OR @n_continue = 2)                        
   BEGIN                                                      
      IF (@b_debug =1)                         
      BEGIN                        
         SELECT 'Updating combinable orders'                        
      END                        
                              
      DECLARE CUR_READ_CombineOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                  
      SELECT A.[Row_No]                       
      FROM #Temp_FinalOrders A                        
      WHERE A.[Row_No] > 0                        
      GROUP BY A.[Row_No]                         
      ORDER BY A.[Row_No] ASC                        
                           
      OPEN CUR_READ_CombineOrders            
                  
      FETCH NEXT FROM CUR_READ_CombineOrders INTO @n_Row_No                       
                           
      WHILE (@@FETCH_STATUS <> -1)                        
      BEGIN -- 1st cursor (Row_no)                        
         BEGIN TRAN                        
                           
         SELECT @n_TotOpenQty = 0                              
                                  
         IF(@n_continue= 1 OR @n_continue =2)                        
         BEGIN                        
            SELECT @c_NewOrderkey=''                        
            SELECT @b_success=1                        
            EXECUTE nspg_getkey                        
            'Order'                        
            ,10                        
            , @c_NewOrderkey OUTPUT                        
            , @b_success OUTPUT                        
            , @n_err OUTPUT                        
            , @c_errmsg OUTPUT                        
         END                        
         IF NOT (@b_success=1)                        
         BEGIN                        
            SELECT @n_continue=3                        
            SET @c_errmsg = N'FAIL MERGING. Unable to acquired new orderkey.'                        
            GOTO EXIT_SP                        
         END                        
                                                         
         SET @c_OrderKey = ''                        
         SET @n_Notes2 = ''                                               
                                      
         SELECT @c_OrderKey = MIN(O.Orderkey),  -- for copy Order data from this Orders           
                @n_TotOpenQty = SUM(OpenQty)                          
         FROM ORDERS O WITH (NOLOCK)       
         JOIN  #Temp_FinalOrders B ON B.ORDERKEY = O.ORDERKEY                        
         WHERE B.Row_no = @n_Row_No                         
                                                      
         TRUNCATE TABLE #temp_OrderDetail         
                        
         IF @b_debug = 1                        
         BEGIN                        
            SELECT @c_NewOrderkey, 0 ,T1.[ExternOrderKey],T1.[ExternLineNo]                         
            ,T1.[Sku],T1.[StorerKey],T1.[ManufacturerSku],T1.[RetailSku],T1.[AltSku],T1.[OriginalQty],T1.[OpenQty],0,0                         
            ,[QtyPreAllocated],[QtyAllocated],[QtyPicked],[UOM],[PackKey],[PickCode],[CartonGroup],[Lot],[ID],[Facility]                         
            ,'0',T1.[UnitPrice],T1.[Tax01],T1.[Tax02],T1.[ExtendedPrice],T1.[UpdateSource],T1.[Lottable01],T1.[Lottable02],T1.[Lottable03]                         
            ,T1.[Lottable04],T1.[Lottable05],T1.[FreeGoodQty],T1.[GrossWeight],T1.[Capacity],T1.[QtyToProcess], T1.[MinShelfLife]                        
            ,T1.[UserDefine01],T1.[UserDefine02],T1.[UserDefine03],T1.[UserDefine04],T1.Orderkey,T2.Externorderkey                        
            ,T1.[UserDefine08],T1.[POkey],T1.[ExternPOKey],T1.[UserDefine10], T1.EnteredQTY ,T1.[OrderKey]    -- *                        
            ,T2.ExternOrderKey,T1.[OrderLineNumber],T1.[Lottable06],T1.[Lottable07],T1.[Lottable08],T1.[Lottable09],T1.[Lottable10] -- *                        
            ,T1.[Lottable11],T1.[Lottable12],T1.[Lottable13],T1.[Lottable14],T1.[Lottable15],T1.[Notes],T1.[Notes2] ,T1.[Channel]   --tlting                        
            , ROW_NUMBER() OVER (ORDER BY T1.OrderKey , T1.[OrderLineNumber]) AS [Row_No]                        
            FROM ORDERDETAIL T1 WITH (NOLOCK)                         
            JOIN #Temp_FinalOrders T2 ON T2.OrderKey = T1.OrderKey                        
            WHERE T2.Row_no = @n_Row_No                         
            ORDER BY T1.OrderKey , T1.[OrderLineNumber]                        
         END                        
                           
         INSERT INTO #temp_OrderDetail( [OrderKey],[OrderLineNumber],[ExternOrderKey],[ExternLineNo]                         
         ,[Sku],[StorerKey],[ManufacturerSku],[RetailSku],[AltSku],[OriginalQty],[OpenQty],[ShippedQty],[AdjustedQty]                       
         ,[QtyPreAllocated],[QtyAllocated],[QtyPicked],[UOM],[PackKey],[PickCode],[CartonGroup],[Lot],[ID],[Facility]                        
         ,[Status],[UnitPrice],[Tax01],[Tax02],[ExtendedPrice],[UpdateSource],[Lottable01],[Lottable02],[Lottable03]                          
         ,[Lottable04],[Lottable05],AddDate   ,AddWho,[FreeGoodQty],[GrossWeight],[Capacity],[QtyToProcess],[MinShelfLife]                      
         ,[UserDefine01],[UserDefine02],[UserDefine03] ,[UserDefine04],[UserDefine05],[UserDefine06],[UserDefine07]                        
         ,UserDefine08, UserDefine09,[POkey],[ExternPOKey],[UserDefine10], EnteredQTY ,[ConsoOrderKey]                         
         ,[ExternConsoOrderKey],[ConsoOrderLineNo],[Lottable06],[Lottable07],[Lottable08],[Lottable09],[Lottable10]                         
         ,[Lottable11],[Lottable12],[Lottable13],[Lottable14],[Lottable15],[Notes],[Notes2], [Channel], ROW_NO )                        
         SELECT @c_NewOrderkey, 0 ,T1.[ExternOrderKey],T1.[ExternLineNo]                         
         ,T1.[Sku],T1.[StorerKey],T1.[ManufacturerSku],T1.[RetailSku],T1.[AltSku],T1.[OriginalQty],T1.[OpenQty],0,0                      
         ,[QtyPreAllocated],[QtyAllocated],[QtyPicked],[UOM],[PackKey],[PickCode],[CartonGroup],[Lot],[ID],[Facility]                    
         ,'0',T1.[UnitPrice],T1.[Tax01],T1.[Tax02],T1.[ExtendedPrice],T1.[UpdateSource],T1.[Lottable01],T1.[Lottable02],T1.[Lottable03]                       
         ,T1.[Lottable04],T1.[Lottable05],AddDate   ,AddWho,T1.[FreeGoodQty],T1.[GrossWeight],T1.[Capacity],T1.[QtyToProcess], T1.[MinShelfLife]                        
         ,T1.[UserDefine01],T1.[UserDefine02],T1.[UserDefine03] ,T1.[UserDefine04],T1.Orderkey,CONVERT(nvarchar(18),T2.Externorderkey),''                       
         ,T1.UserDefine08, '',T1.[POkey],T1.[ExternPOKey],T1.[UserDefine10], T1.EnteredQTY ,T1.[OrderKey]    -- *                        
         ,T2.ExternOrderKey,T1.[OrderLineNumber],T1.[Lottable06],T1.[Lottable07],T1.[Lottable08],T1.[Lottable09],T1.[Lottable10]  -- *                        
         ,T1.[Lottable11],T1.[Lottable12],T1.[Lottable13],T1.[Lottable14],T1.[Lottable15],T1.Notes,T1.[Notes2] , T1.[Channel] --tlting                        
         , ROW_NUMBER() OVER (ORDER BY T1.OrderKey , T1.[OrderLineNumber]) AS [Row_No]                        
         FROM ORDERDETAIL T1 WITH (NOLOCK)                         
         JOIN #Temp_FinalOrders T2 ON T2.OrderKey = T1.OrderKey                        
         WHERE T2.Row_no = @n_Row_No                         
         AND exists ( Select 1 FROM Orders (NOLOCK) where Orders.orderkey = T1.orderkey and Orders.status  <> 'CANC' and Orders.SOStatus  <> 'PENDCANC'    )  -- kocy02                 
         ORDER BY T1.OrderKey , T1.[OrderLineNumber]                    
                         
         IF @b_debug = 1                        
         BEGIN                        
            SELECT * FROM #temp_OrderDetail                        
         END                        
                           
         IF NOT EXISTS(SELECT 1 FROM #temp_OrderDetail)                        
         BEGIN                        
            ROLLBACK TRAN                  

            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                 , @n_err = 83050 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                               + ': FAIL MERGING. Unable to INSERT Child orderdetail into @temp_OrderDetail. (isp_RCM_WAVE_OrdersMerging)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_errmsg) + ' ) '
                                         
            GOTO EXIT_SP                        
         END                                                          
                            
         SET @c_GetExternOrderList = ''                 
                                 
         DECLARE CUR_READ_Orderkey_CombineOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                        
         SELECT #Temp_FinalOrders.[OrderKey],#Temp_FinalOrders.[ExternOrderKey]                  
         FROM #Temp_FinalOrders               
         WHERE [Row_No] = @n_Row_No              
                                                    
         OPEN CUR_READ_Orderkey_CombineOrders                        
         FETCH NEXT FROM  CUR_READ_Orderkey_CombineOrders INTO @c_OrderKey, @c_ExternOrderKey    
                           
         WHILE (@@FETCH_STATUS <>-1)                        
         BEGIN -- 2nd cursor (orderkey)                        
                                  
            -- if Orders not Cancel. still original status                      
            IF exists ( Select 1 from Orders (NOLOCK) where [OrderKey]  = @c_OrderKey                          
                          AND Status = '0' AND SOStatus = '0'         )                      
            BEGIN                        
               UPDATE [dbo].[ORDERS]                         
               SET  POKey        = @c_NewOrderkey                        
                  ,[SOStatus]    = 'HOLD'                        
                  ,[OrderGroup]  = 'CHILD_ORD'                        
                  ,TrafficCop  = NULL                        
                  , EditDate = GETDATE()                        
                  , EditWho = SUSER_SNAME()                        
               WHERE [OrderKey]  = @c_OrderKey                        
                              
               UPDATE dbo.Orderdetail                          
               SET ConsoOrderKey = @c_NewOrderkey,                        
                  TrafficCop = NULL,                        
                  EditDate = GETDATE(),                        
                  EditWho = SUSER_SNAME()                        
               FROM dbo.Orderdetail                       
               WHERE Orderdetail.Orderkey = @c_OrderKey                        
               and  exists ( Select 1 from Orders (NOLOCK) where Orders.orderkey =  Orderdetail.orderkey and Orders.SOStatus = 'HOLD'                       
                         and Orders.OrderGroup = 'CHILD_ORD' )                      
               
   			       DELETE dbo.WAVEDETAIL WHERE OrderKey = @c_OrderKey   ---remove child order from wave
             
   		         IF ISNULL(RTRIM(@c_ExternOrderKey) , '') = ''     
   		         BEGIN
                  SET @c_ExternOrderKey = ''                        
               END
   		   
               IF @c_ExternOrderKey <> ''                        
               BEGIN                        
                  IF @c_GetExternOrderList = ''                        
                  BEGIN                        
                     SET @c_GetExternOrderList = @c_ExternOrderKey                        
                  END                        
                  ELSE                        
                  BEGIN                        
                     SET @c_GetExternOrderList = @c_GetExternOrderList + ',' + @c_ExternOrderKey                        
                  END                        
               END                        
                                        
               IF(@b_debug = 1)                        
               BEGIN                         
                  SELECT  @c_GetExternOrderList AS 'GetExternOrderList'                        
               END                                          
            END -- if exists                                 
         FETCH NEXT FROM CUR_READ_Orderkey_CombineOrders INTO @c_OrderKey, @c_ExternOrderKey        
         END -- 2nd cursor (orderkey)                        
         CLOSE CUR_READ_Orderkey_CombineOrders                        
         DEALLOCATE CUR_READ_Orderkey_CombineOrders            
                                       
         INSERT INTO ORDERS ([OrderKey],[StorerKey], [ExternOrderKey], [OrderDate], [DeliveryDate], [Priority],                         
         [ConsigneeKey], [C_Contact1], [C_Contact2], [C_Company],[C_Address1], [C_Address2], [C_Address3], [C_Address4],                         
         [C_City], [C_State], [C_Zip],C_Country,C_ISOCntryCode,[C_Phone1], [C_Phone2], C_Fax1,C_Fax2,C_vat,[BuyerPO],                         
         BillToKey, B_contact1,B_Contact2,B_Company,B_Address1,B_Address2,B_Address3,B_Address4,B_City,B_State,B_Zip,                        
         B_Country,B_ISOCntryCode,B_Phone1,B_Phone2,B_Fax1,B_Fax2,B_Vat,IncoTerm,                     
         [PmtTerm], [OpenQty], [Status],DischargePlace,DeliveryPlace,IntermodalVehicle,CountryOfOrigin,CountryDestination,                        
         UpdateSource, [Type], [OrderGroup], [Stop], Notes, AddDate, AddWho, ContainerType, ContainerQty, [SOSTATUS],                         
         [InvoiceAmount], [Salesman], [Notes2],SectionKey, [Facility], LabelPrice, [UserDefine01], [UserDefine03],[UserDefine04], [UserDefine05], -- kocy01                      
         [UserDefine08], Issued, DeliveryNote, [SpecialHandling], [RoutingTool], M_Contact1 ,M_Contact2, [M_Company],                         
         M_Address1,M_Address2,M_Address3,M_Address4,M_City,M_State,M_Zip,M_Country,M_ISOCntryCode,M_Phone1,M_Phone2,M_Fax1,                        
         M_Fax2,M_vat, [ShipperKey], [DocType] , [TrackingNo], [ECOM_PRESALE_FLAG], [ECOM_SINGLE_Flag] )                         
         SELECT  @c_NewOrderkey, Storerkey, @c_NewOrderkey, OrderDate, DeliveryDate, [Priority],                         
         ConsigneeKey, C_contact1, C_Contact2, C_Company, C_Address1, C_Address2, C_Address3, C_Address4,                         
         C_City, C_State, C_Zip,C_Country, C_ISOCntryCode,C_Phone1,C_Phone2, C_Fax1,C_Fax2,C_vat, BuyerPO,                         
         '','','','','','','','','','','','','','','','','','',IncoTerm,                        
         PmtTerm, @n_TotOpenQty, '0','','','','','','', [Type], 'COM_ORDER',[STOP],'', AddDate, AddWho, ContainerType,0, 0,                          
         InvoiceAmount, Salesman, @c_GetExternOrderList/*@n_Notes2 [Notes2]*/, SectionKey,Facility, '', UserDefine01,                         
         Userdefine03,UserDefine04, UserDefine05, UserDefine08, 'N','', SpecialHandling, RoutingTool, '','', M_Company,                     
         '','','','','','','','','','','','','','', ShipperKey, DocType  , [TrackingNo], [ECOM_PRESALE_FLAG], [ECOM_SINGLE_Flag]
         FROM ORDERS WITH (NOLOCK)                         
         WHERE ORDERKEY = @c_OrderKey   -- top 1 for copy order infor                        
         AND Orders.SOStatus = 'HOLD' and Orders.OrderGroup = 'CHILD_ORD'                        
                           
         IF EXISTS ( SELECT 1 FROM #temp_OrderDetail )                        
         AND EXISTS ( SELECT 1 FROM ORDERS (NOLOCK) WHERE orderkey = @c_NewOrderkey and status = '0' and SOSTATUS = '0')                        
         BEGIN                        
            --INSERT INTO dbo.ORDERDETAIL                        
            INSERT INTO dbo.ORDERDETAIL ( [OrderKey],[OrderLineNumber],[ExternOrderKey],[ExternLineNo]                                  
   		      ,[Sku],[StorerKey],[ManufacturerSku],[RetailSku],[AltSku],[OriginalQty],[OpenQty],[ShippedQty],[AdjustedQty]   
            ,[QtyPreAllocated],[QtyAllocated],[QtyPicked],[UOM],[PackKey],[PickCode],[CartonGroup],[Lot],[ID],[Facility]                      
            ,[Status],[UnitPrice],[Tax01],[Tax02],[ExtendedPrice],[UpdateSource],[Lottable01],[Lottable02],[Lottable03]                         
            ,[Lottable04],[Lottable05],AddDate   ,AddWho,[FreeGoodQty],[GrossWeight],[Capacity],[QtyToProcess],[MinShelfLife]                        
            ,[UserDefine01],[UserDefine02],[UserDefine03],[UserDefine04],[UserDefine05],[UserDefine06],[UserDefine07]                         
            ,UserDefine08, UserDefine09,[POkey],[ExternPOKey],[UserDefine10], EnteredQTY ,[ConsoOrderKey]                         
            ,[ExternConsoOrderKey],[ConsoOrderLineNo],[Lottable06],[Lottable07],[Lottable08],[Lottable09],[Lottable10]                         
            ,[Lottable11],[Lottable12],[Lottable13],[Lottable14],[Lottable15],[Notes],[Notes2], [Channel] )                        
                                  
            SELECT [OrderKey], RIGHT('00000' + CAST(ROW_NO AS varchar), 5) ,[ExternOrderKey],[ExternLineNo]                         
            ,[Sku],[StorerKey],[ManufacturerSku],[RetailSku],[AltSku],[OriginalQty],[OpenQty],[ShippedQty],[AdjustedQty]                         
            ,[QtyPreAllocated],[QtyAllocated],[QtyPicked],[UOM],[PackKey],[PickCode],[CartonGroup],[Lot],[ID],[Facility]                         
            ,[Status],[UnitPrice],[Tax01],[Tax02],[ExtendedPrice],[UpdateSource],[Lottable01],[Lottable02],[Lottable03]                         
            ,[Lottable04],[Lottable05],AddDate   ,AddWho,[FreeGoodQty],[GrossWeight],[Capacity],[QtyToProcess],[MinShelfLife]                        
            ,[UserDefine01],[UserDefine02],[UserDefine03],[UserDefine04],[UserDefine05],[UserDefine06],[UserDefine07]                         
            ,UserDefine08, UserDefine09,[POkey],[ExternPOKey],[UserDefine10], EnteredQTY ,[ConsoOrderKey]                         
            ,[ExternConsoOrderKey],[ConsoOrderLineNo],[Lottable06],[Lottable07],[Lottable08],[Lottable09],[Lottable10]                         
            ,[Lottable11],[Lottable12],[Lottable13],[Lottable14],[Lottable15],[Notes],[Notes2] , [Channel]                        
            FROM #temp_OrderDetail                        
            WHERE EXISTS  ( Select 1 from ORDERS (NOLOCK) where ORDERS.orderkey =   #temp_OrderDetail.ConsoOrderKey                        
                           AND Orders.SOStatus = 'HOLD' and Orders.OrderGroup = 'CHILD_ORD'  )                      
            ORDER BY ROW_NO                         
                           
            IF @@ROWCOUNT = 0 OR @@ERROR <> 0                    
            BEGIN                        
               ROLLBACK TRAN                        

               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 83060 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                  + ': FAIL MERGING, Unable to insert parent orders orderdetail. (isp_RCM_WAVE_OrdersMerging)' + ' ( ' + ' SQLSvr MESSAGE='
                                     + RTRIM(@c_errmsg) + ' ) '

               GOTO EXIT_SP                        
            END                        
         END                
   	  
   	     IF @c_Option1 = '1'
   	     BEGIN
   	        --INSERT INTO dbo.DocInfo           
   	        INSERT INTO dbo.DocInfo ([TableName],[Key1],[Key2],[Key3],[StorerKey],[LineSeq],[Data],[DataType],[StoredProc])
         
   		      SELECT [TableName],TOD.OrderKey,RIGHT('00000' + CAST(TOD.ROW_NO AS varchar), 5),[Key3],TOD.[StorerKey],[LineSeq],[Data],[DataType],[StoredProc] 
   		      FROM #temp_OrderDetail TOD WITH (NOLOCK) 
   		      JOIN dbo.DocInfo PAI WITH (NOLOCK) ON PAI.StorerKey = TOD.StorerKey AND TOD.ConsoOrderKey=PAI.Key1 AND TOD.ConsoOrderLineNo = PAI.Key2 
   		      WHERE EXISTS  ( Select 1 from ORDERS (NOLOCK) where ORDERS.orderkey = TOD.ConsoOrderKey                        
                            AND Orders.SOStatus = 'HOLD' and Orders.OrderGroup = 'CHILD_ORD'  )              
   	     END
   
         SET @b_success = 0  
         SET @c_Wavedetailkey = ''  
          
         EXEC dbo.nspg_GetKey                  
             @KeyName = 'WavedetailKey'      
            ,@fieldlength = 10      
            ,@keystring = @c_Wavedetailkey OUTPUT      
            ,@b_Success = @b_success OUTPUT      
            ,@n_err = @n_err OUTPUT      
            ,@c_errmsg = @c_errmsg OUTPUT  
            ,@b_resultset = 0      
            ,@n_batch     = 1             
              
         IF @b_Success = 1  
         BEGIN           
            INSERT INTO WAVEDETAIL(Wavekey, Wavedetailkey, Orderkey)  
            VALUES (@c_Wavekey, @c_Wavedetailkey, @c_NewOrderkey)  
            
            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
              SELECT @n_continue = 3
              SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                   , @n_err = 83070 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
              SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                 + ': Insert Wavedetail Failed. (isp_RCM_WAVE_OrdersMerging)' + ' ( ' + ' SQLSvr MESSAGE='
                                    + RTRIM(@c_errmsg) + ' ) '

              GOTO EXIT_SP            
            END  
         END     
   
         COMMIT TRAN                   
                           
         FETCH NEXT FROM CUR_READ_CombineOrders INTO @n_Row_No                        
      END -- 1st cursor (Row_no)                        
      CLOSE CUR_READ_CombineOrders                        
      DEALLOCATE CUR_READ_CombineOrders           
                                
   EXIT_SP:                          
                                 
      IF @n_Continue=3  -- Error Occured - Process And Return                              
      BEGIN                              
         SELECT @b_Success = 0                              
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt                              
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
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_RCM_WAVE_OrdersMerging'             
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012                              
         RETURN                              
      END                              
      ELSE                         
      BEGIN                              
         SELECT @b_Success = 1                              
         WHILE @@TRANCOUNT > @n_StartTCnt                              
         BEGIN                              
            COMMIT TRAN                              
      END                              
         RETURN                              
      END                           
   END          
                                              
                        
END   
  
  

GO