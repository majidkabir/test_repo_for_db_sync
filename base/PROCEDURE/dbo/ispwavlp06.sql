SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  ispWAVLP06                                         */
/* Creation Date: 16-SEP-2020                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-14636 Converse generate load plan                      */
/*           Storerconfig: WAVEGENLOADPLAN                              */
/*                                                                      */
/* Input Parameters:  @c_WaveKey  - (WaveKey)                           */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC Generate Load Plan By Consignee                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/* 12-Nov-2021 NJOW01   1.0  WMS-18368 update sequence no to load plan  */
/* 12-Nov-2021 NJOW01   1.0  DEVOPS combine script                      */
/* 30-Aug-2022 NJOW02   1.1  WMS-20675 allow split load plan for child  */
/*                           order if over qty limit. Optimize order qty*/
/*                           in a load plan                             */
/* 16-Mar-2023 NJOW03   1.2  WMS-22019 Cater for B2C wave using different*/
/*                           generate load logic                        */
/************************************************************************/
CREATE   PROC [dbo].[ispWAVLP06]
   @c_WaveKey NVARCHAR(10),
   @b_Success int OUTPUT,
   @n_err     int OUTPUT,
   @c_errmsg  NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON   -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Facility             NVARCHAR( 5)           
           ,@c_StorerKey           NVARCHAR( 15)
           ,@c_OrdUDF05            NVARCHAR( 10)
           ,@c_GroupField          NVARCHAR( 30)
           ,@c_MaxQtyPerLoad       NVARCHAR( 30)        
           ,@n_MaxQtyPerLoad       BIGINT   
           ,@n_MaxOrderPerLoad     INT
           ,@c_loadkey             NVARCHAR( 10)
           ,@n_loadcount           INT
           ,@c_OrderKey            NVARCHAR( 10)
           ,@c_ConsigneeKey        NVARCHAR( 15)
           ,@c_Priority            NVARCHAR( 10)
           ,@c_C_Company           NVARCHAR( 45)
           ,@c_ExternOrderKey      NVARCHAR( 50)  
           ,@c_Route               NVARCHAR( 10)
           ,@d_Delivery_Date       DATETIME
           ,@c_OrderType           NVARCHAR( 10)
           ,@c_Door                NVARCHAR( 10)
           ,@c_DeliveryPlace       NVARCHAR( 30)
           ,@c_OrderStatus         NVARCHAR( 10)
           ,@d_OrderDate           DATETIME           
           ,@n_TotWeight           FLOAT
           ,@n_TotCube             FLOAT
           ,@n_TotOrdLine          INT
           ,@n_continue            INT
           ,@n_StartTranCnt        INT
           ,@b_debug               INT
           ,@n_Ordercnt            INT
           ,@n_TotOrdQty           INT
           ,@n_TotLoadQty          INT
           ,@c_AutoUpdSupOrdflag   NVARCHAR(30)                     
           ,@c_SuperOrderFlag      NVARCHAR(1)           
           ,@c_TableName           NVARCHAR(30)
           ,@c_ColumnName          NVARCHAR(30)         
           ,@c_ColumnType          NVARCHAR(10)
           ,@c_FieldVal01          NVARCHAR(60)
           ,@c_FieldVal01Name      NVARCHAR(60)
           ,@c_SQLDYN01            NVARCHAR(2000)
           ,@c_SQLDYN02            NVARCHAR(2000)
           ,@c_BuyerPO             NVARCHAR(20)
           --,@c_PrevBuyerPO         NVARCHAR(20)
           ,@n_NoofChildOrders     INT
           ,@n_TotalChildQty       INT
           ,@n_RowID               INT --NJOW02
                  
   IF @n_err = 0
      SET @b_debug = 1

   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @n_err = 0, @n_loadcount = 0, @b_Success = 1, @c_errmsg= '', @n_MaxOrderPerLoad = 99999
  
   -------------------------- Wave Validation ------------------------------
   IF NOT EXISTS(SELECT 1 FROM WaveDetail WITH (NOLOCK) WHERE WaveKey = @c_WaveKey)
   BEGIN
     SELECT @n_continue = 3
     SELECT @n_err = 63500
     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Orders being populated into WaveDetail. (ispWAVLP06)"
     GOTO RETURN_SP
   END
   
   --NJOW03 S
   IF EXISTS(SELECT TOP 1 1 
             FROM WAVEDETAIL WD (NOLOCK)
             JOIN ORDERDETAIL OD (NOLOCK) ON WD.Orderkey = OD.Orderkey
             WHERE OD.Channel = 'B2C'
             AND WD.Wavekey = @c_Wavekey)
   BEGIN
      EXEC ispWAVLP03
           @c_WaveKey = @c_Wavekey
         , @b_Success = @b_Success  OUTPUT
         , @n_err     = @n_err      OUTPUT
         , @c_errmsg  = @c_errmsg   OUTPUT   	
         
       RETURN         
   END                       
   --NJOW03 E
   
   --NJOW02
   CREATE TABLE #TMP_ORDER (RowID INT IDENTITY(1,1) PRIMARY KEY, OrderKey NVARCHAR(10), BuyerPO NVARCHAR(20) NULL, NoofChildOrders INT, TotalChildQty INT, OrderQty INT)
   
   IF @@TRANCOUNT = 0 
      BEGIN TRAN
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 	  	
   	  SELECT TOP 1 @c_Storerkey = O.Storerkey,
   	               @c_Facility = O.Facility
   	  FROM WAVEDETAIL WD (NOLOCK)
   	  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
   	  WHERE WD.Wavekey = @c_Wavekey 	  
  
      SELECT @b_success = 0
      EXECUTE nspGetRight
          @c_facility,
          @c_StorerKey,          
          NULL,   -- Sku
          'AutoUpdSupOrdflag', 
          @b_success    output,
          @c_AutoUpdSupOrdflag OUTPUT,
          @n_err               OUTPUT,
          @c_errmsg            OUTPUT 	  
      
      IF @b_Success <> 1
         SELECT @n_continue = 3
      
      IF @c_AutoUpdSupOrdflag = '1' 
         SET @c_SuperOrderFlag = 'Y'
      ELSE
         SET @c_SuperOrderFlag = 'N'
   	
   	 --get the parent-child orders information. Child orders are group by buyer PO
     SELECT ORDERS.BuyerPO, COUNT(DISTINCT ORDERS.Orderkey) AS NoofOrders, 
            CASE WHEN MAX(ORDERS.Userdefine05) = 'Y' THEN 'Y' ELSE 'N' END AS Userdefine05,  --if any child order userdefine05 is Y Set to Y
            SUM(ORDERDETAIL.OpenQty) AS TotalQty
     INTO #PARENTORDER
     FROM ORDERS WITH (NOLOCK)
     JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey 
     JOIN WAVEDETAIL WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) 
     WHERE WD.WaveKey = @c_WaveKey 
     AND ORDERS.Status NOT IN ('9','CANC') 
     AND ISNULL(ORDERS.Loadkey,'') = ''
     AND ISNULL(ORDERS.BuyerPO,'') <> ''
     GROUP BY ORDERS.BuyerPO
   	
   	 --Loop the order grouping setting
     DECLARE cur_SETUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Short, UDF01, UDF02
         FROM CODELKUP (NOLOCK)
         WHERE Listname = 'WV-CONVLD'
         AND Short IN('Y','N')
         AND ISNULL(UDF01,'') <> ''
         AND Storerkey = @c_Storerkey
         ORDER BY Code
  
     OPEN cur_SETUP
  
     FETCH NEXT FROM cur_SETUP INTO @c_OrdUDF05, @c_GroupField, @c_MaxQtyPerLoad
     
     WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
     BEGIN   	     	  
     	  IF @b_debug = 1 
     	     PRINT '@c_OrdUDF05=' + @c_OrdUDF05 + ' @c_GroupField='+ @c_GroupField + ' @c_MaxQtyPerLoad=' + @c_MaxQtyPerLoad
     	     
        SET @c_TableName = LEFT(@c_GroupField, CharIndex('.', @c_GroupField) - 1)
        SET @c_ColumnName = SUBSTRING(@c_GroupField,
                            CharIndex('.', @c_GroupField) + 1, LEN(@c_GroupField) - CharIndex('.', @c_GroupField))
             
        IF ISNULL(RTRIM(@c_TableName), '') <> 'ORDERS'
        BEGIN
           SELECT @n_continue = 3
           SELECT @n_err = 63510
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Grouping Only Allow Refer To Orders Table's Fields. Invalid Table: "+RTRIM(@c_GroupField)+" (ispWAVLP06)"
           BREAK
        END   	
        
        SET @c_ColumnType = ''
        SELECT @c_ColumnType = DATA_TYPE
        FROM   INFORMATION_SCHEMA.COLUMNS
        WHERE  TABLE_NAME = @c_TableName
        AND    COLUMN_NAME = @c_ColumnName
  
        IF ISNULL(RTRIM(@c_ColumnType), '') = ''
        BEGIN
           SELECT @n_continue = 3
           SELECT @n_err = 63520
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_GroupField)+ ". (ispWAVLP06)"
           BREAK
        END
  
        IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')
        BEGIN
           SELECT @n_continue = 3
           SELECT @n_err = 63530
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Numeric/Text Column Type Is Not Allowed For Load Plan Grouping: " + RTRIM(@c_GroupField)+ ". (ispWAVLP06)"
           BREAK
        END      
        
        IF ISNUMERIC(@c_MaxQtyPerLoad)=1
           SET @n_MaxQtyPerLoad = CAST(@c_MaxQtyPerLoad AS BIGINT)
        ELSE
           SET @n_MaxQtyPerLoad =  99999999
        
        --Loop the grouping value. e.g. it can be consigneekey or orderkey          
        /*SELECT @c_SQLDYN01 = 'DECLARE cur_LPGroup CURSOR FAST_FORWARD READ_ONLY FOR '
        + ' SELECT ' + @c_GroupField
        + ' FROM ORDERS WITH (NOLOCK) '
        + ' JOIN WaveDetail WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
        +'  WHERE WD.WaveKey = @c_Wavekey ' +  
        + ' AND ISNULL(ORDERS.Loadkey,'''') = '''' '
        + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
        + ' AND ORDERS.Userdefine05 = @c_OrdUDF05 '
        + ' GROUP BY ' + @c_GroupField
        + ' ORDER BY ' + @c_GroupField*/
        
        IF @c_GroupField = 'ORDERS.ORDERKEY'
        BEGIN
           SELECT @c_SQLDYN01 = 'DECLARE cur_LPGroup CURSOR FAST_FORWARD READ_ONLY FOR '
           + ' SELECT CASE WHEN P.BuyerPO IS NOT NULL THEN P.BuyerPO ELSE ' + @c_GroupField + ' END, '    --get and group by buyerpo value if have multiple child orders
           + '        CASE WHEN P.BuyerPO IS NOT NULL THEN ''ORDERS.BUYERPO'' ELSE ''' + @c_GroupField + ''' END '  
           + ' FROM ORDERS WITH (NOLOCK) '
           + ' JOIN WaveDetail WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
           + ' LEFT JOIN #PARENTORDER P ON ORDERS.BuyerPO =  P.BuyerPO '
           + ' WHERE WD.WaveKey = @c_Wavekey ' +  
           + ' AND ISNULL(ORDERS.Loadkey,'''') = '''' '
           + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
           + ' AND ((ORDERS.Userdefine05 = @c_OrdUDF05 AND P.BuyerPO IS NULL) OR P.Userdefine05 = @c_OrdUDF05) '
           + ' GROUP BY CASE WHEN P.BuyerPO IS NOT NULL THEN P.BuyerPO ELSE ' + @c_GroupField + ' END, '
           + '          CASE WHEN P.BuyerPO IS NOT NULL THEN ''ORDERS.BUYERPO'' ELSE ''' + @c_GroupField + ''' END ' 
           + ' ORDER BY CASE WHEN MAX(P.BuyerPO) IS NOT NULL THEN 1 ELSE 2 END, 1'
        END
        ELSE
        BEGIN
           SELECT @c_SQLDYN01 = 'DECLARE cur_LPGroup CURSOR FAST_FORWARD READ_ONLY FOR '
           + ' SELECT ' + @c_GroupField + ',''' + @c_GroupField + ''''  
           + ' FROM ORDERS WITH (NOLOCK) '
           + ' JOIN WaveDetail WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
           + ' LEFT JOIN #PARENTORDER P ON ORDERS.BuyerPO =  P.BuyerPO '
           + '  WHERE WD.WaveKey = @c_Wavekey ' +  
           + ' AND ISNULL(ORDERS.Loadkey,'''') = '''' '
           + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
           + ' AND ((ORDERS.Userdefine05 = @c_OrdUDF05 AND P.BuyerPO IS NULL) OR P.Userdefine05 = @c_OrdUDF05) '
           + ' GROUP BY ' + @c_GroupField
                   	
        END
  
        EXEC sp_executesql @c_SQLDYN01,                                                      
           N'@c_Wavekey NVARCHAR(10), @c_OrdUDF05 NVARCHAR(30)',                      
           @c_Wavekey
          ,@c_OrdUDF05                                                     
  
        OPEN cur_LPGroup
        
        FETCH NEXT FROM cur_LPGroup INTO @c_FieldVal01, @c_FieldVal01Name  
  
        WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
        BEGIN      	 
        	 IF @b_debug = 1
        	    PRINT '@c_FieldVal01=' + @c_FieldVal01 + '@c_FieldVal01Name=' + @c_FieldVal01Name
        	    
           SET @c_Loadkey = ''
           SET @n_TotLoadQty = 0
           SET @b_success = 0         
           EXECUTE nspg_GetKey
              'LOADKEY',
              10,
              @c_loadkey     OUTPUT,
              @b_success     OUTPUT,
              @n_err         OUTPUT,
              @c_errmsg      OUTPUT
           
           IF @b_success <> 1
           BEGIN
             SELECT @n_continue = 3
           END

           SELECT @n_loadcount = @n_loadcount + 1         
           
           INSERT INTO LoadPlan (LoadKey, Facility, SuperOrderFlag, Load_Userdef1, Userdefine02)
           VALUES (@c_loadkey, @c_Facility, @c_SuperOrderFlag, @c_FieldVal01, CAST(@n_loadcount AS NVARCHAR))  --NJOW01
                      
           IF @b_debug = 1
              PRINT 'New1 @c_Loadkey=' + @c_Loadkey           

           DELETE FROM #TMP_ORDER
           --SELECT @c_SQLDYN02 = 'DECLARE cur_loadpland CURSOR FAST_FORWARD READ_ONLY FOR '
           SELECT @c_SQLDYN02 = 'INSERT INTO #TMP_ORDER (Orderkey, BuyerPO, NoofChildOrders, TotalChildQty, OrderQty) '  --NJOW02  
           + ' SELECT ORDERS.OrderKey, ISNULL(ORDERS.BuyerPO,''''), ISNULL(P.NoofOrders,0), ISNULL(P.TotalQty,0), ORDERS.OpenQty '
           + ' FROM ORDERS WITH (NOLOCK) '
           + ' JOIN WAVEDETAIL WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
           + ' LEFT JOIN #PARENTORDER P ON ORDERS.BuyerPO =  P.BuyerPO '
           + ' WHERE WD.WaveKey = @c_WaveKey ' +
           + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
           + ' AND ISNULL(ORDERS.Loadkey,'''') = '''' '
           + ' AND ((ORDERS.Userdefine05 = @c_OrdUDF05 AND P.BuyerPO IS NULL) OR P.Userdefine05 = @c_OrdUDF05) '
           + ' AND ' + RTRIM(@c_FieldVal01Name) + ' = @c_FieldVal01 ' + 
           + ' ORDER BY ORDERS.BuyerPO, ORDERS.OrderKey '
  
          EXEC sp_executesql @c_SQLDYN02,
               N'@c_Wavekey NVARCHAR(10), @c_OrdUDF05 NVARCHAR(30), @c_FieldVal01 NVARCHAR(60)',
               @c_Wavekey,
               @c_OrdUDF05,             
               @c_FieldVal01
  
           --OPEN cur_loadpland
  
           --FETCH NEXT FROM cur_loadpland INTO @c_OrderKey, @c_BuyerPO, @n_NoofChildOrders, @n_TotalChildQty
           
           SET @n_Ordercnt = 0           
           --SET @c_PrevBuyerPO = ''
           
           DECLARE cur_BuyerPO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
              SELECT DISTINCT BuyerPO
              FROM #TMP_ORDER 
              ORDER BY BuyerPO
              
           OPEN cur_BuyerPO   
           
           FETCH NEXT FROM cur_BuyerPO INTO @c_BuyerPO

           WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)           
           BEGIN
              --WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
              WHILE 1=1 AND @n_continue IN(1,2)  --NJOW02 S
              BEGIN         	           	  
              	  SELECT @n_RowID = 0, @c_Orderkey = '', @n_NoofChildOrders = 0, @n_TotalChildQty = 0
              	  
              	  --find the order can fit the load
              	  IF @c_BuyerPO <> ''
              	  BEGIN
              	     SELECT TOP 1 @n_RowID = RowID,
              	            @c_Orderkey = Orderkey, 
              	            --@c_BuyerPO = BuyerPO,
              	            @n_NoofChildOrders =  NoofChildOrders, 
              	            @n_TotalChildQty = TotalChildQty
              	     FROM #TMP_ORDER
              	     WHERE BuyerPO = @c_BuyerPO
              	     AND OrderQty <= (@n_MaxQtyPerLoad - @n_TotLoadQty)
              	     ORDER BY OrderQty DESC, RowID
              	  END
              	  ELSE
              	  BEGIN
              	     SELECT TOP 1 @n_RowID = RowID,
              	            @c_Orderkey = Orderkey, 
              	            --@c_BuyerPO = BuyerPO,
              	            @n_NoofChildOrders =  NoofChildOrders, 
              	            @n_TotalChildQty = TotalChildQty
              	     FROM #TMP_ORDER
              	     WHERE BuyerPO = @c_BuyerPO
              	     AND OrderQty <= (@n_MaxQtyPerLoad - @n_TotLoadQty)
              	     ORDER BY RowID
              	  END
              	  
              	  --find order follow the sequence and will create new load plan
              	  IF @n_RowID = 0
              	  BEGIN
              	     SELECT TOP 1 @n_RowID = RowID,
              	            @c_Orderkey = Orderkey, 
              	            --@c_BuyerPO = BuyerPO,
              	            @n_NoofChildOrders =  NoofChildOrders, 
              	            @n_TotalChildQty = TotalChildQty
              	     FROM #TMP_ORDER
              	     WHERE BuyerPO = @c_BuyerPO
              	     ORDER BY RowID
              	  END
              	  
              	  IF @n_RowID = 0
              	     BREAK
              	  
              	  --NJOW02 E
              	  
              	  IF @b_debug = 1
              	     PRINT '@c_OrderKey=' + @c_OrderKey + ' @c_BuyerPO=' +  @c_BuyerPO + ' @n_NoofChildOrders=' + CAST(@n_NoofChildOrders AS NVARCHAR) + ' @n_TotalChildQty=' + CAST(@n_TotalChildQty AS NVARCHAR)
              	     
                 IF (SELECT COUNT(1) FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @c_OrderKey) = 0
                 BEGIN
                    SELECT @d_OrderDate = O.OrderDate,
                           @d_Delivery_Date = O.DeliveryDate,
                           @c_OrderType = O.Type,
                           @c_Door = O.Door,
                           @c_Route = O.Route,
                           @c_DeliveryPlace = O.DeliveryPlace,
                           @c_OrderStatus = O.Status,
                           @c_priority = O.Priority,
                           @n_totweight = SUM(OD.OpenQty * SKU.StdGrossWgt),
                           @n_totcube = SUM(OD.OpenQty * SKU.StdCube),
                           @n_TotOrdLine = COUNT(DISTINCT OD.OrderLineNumber),
                           @c_C_Company = O.C_Company,
                           @c_ExternOrderkey = O.ExternOrderkey,
                           @c_Consigneekey = O.Consigneekey,
                           @n_totOrdQty = SUM(OD.OpenQty)
                    FROM Orders O WITH (NOLOCK)
                    JOIN Orderdetail OD WITH (NOLOCK) ON (O.Orderkey = OD.Orderkey)
                    JOIN SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku)
                    WHERE O.OrderKey = @c_OrderKey
                    GROUP BY O.OrderDate, O.DeliveryDate, O.Type, O.Door, O.Route, O.DeliveryPlace,
                             O.Status, O.Priority, O.C_Company, O.ExternOrderkey, O.Consigneekey
                 	
                 	 --IF @n_NoofChildOrders > 1  --if have many child order, change the counter when buyerpo(parent) changed.
                 	 --BEGIN
                 	 --	  IF @c_PrevBuyerPO <> @c_BuyerPO  
                 	 --	  BEGIN               	 
                 	 --	  	 SET @n_totOrdQty = @n_TotalChildQty 
                    --      SET @n_Ordercnt = @n_Ordercnt + @n_NoofChildOrders               	               	               	 
                 	 --      SET @n_TotLoadQty = @n_TotLoadQty + @n_totOrdQty
                 	 --   END   
                 	 --END
                 	 --ELSE
                 	 --BEGIN   
                 	 	  --SET @n_NoofChildOrders = 1
                 	    SET @n_Ordercnt = @n_Ordercnt + 1 --@n_NoofChildOrders              	               	               	 
                 	    SET @n_TotLoadQty = @n_TotLoadQty + @n_totOrdQty
                 	 --END
                 	 
                 	 IF @b_debug = 1 
                 	    PRINT '@n_TotLoadQty=' + CAST(@n_TotLoadQty AS NVARCHAR) 
                 	    
                 	 IF (@n_Ordercnt > @n_MaxOrderPerLoad OR @n_TotLoadQty > @n_MaxQtyPerLoad) --AND NOT (@n_NoofChildOrders > 1 AND @c_PrevBuyerPO = @c_BuyerPO) --NJOW02 removed
                 	 BEGIN
                 	 	  SET @c_Loadkey = ''
                       SET @n_TotLoadQty = @n_totOrdQty           	 	  
                       SET @n_Ordercnt = 1 --@n_NoofChildOrders
                       SET @b_success = 0         
                       EXECUTE nspg_GetKey
                          'LOADKEY',
                          10,
                          @c_loadkey     OUTPUT,
                          @b_success     OUTPUT,
                          @n_err         OUTPUT,
                          @c_errmsg      OUTPUT
                       
                       IF @b_success <> 1
                       BEGIN
                         SELECT @n_continue = 3
                       END
                       
                       INSERT INTO LoadPlan (LoadKey, Facility, SuperOrderFlag, Load_Userdef1)
                       VALUES (@c_loadkey, @c_Facility, @c_SuperOrderFlag, @c_FieldVal01)
                       
                       SELECT @n_loadcount = @n_loadcount + 1                     	 	
              
                 	 	  IF @b_debug = 1
                 	 	     PRINT 'New2 @c_Loadkey=' + @c_Loadkey
                 	 END
                 	 
                    EXEC isp_InsertLoadplanDetail
                         @cLoadKey          = @c_LoadKey,
                         @cFacility         = @c_Facility,
                         @cOrderKey         = @c_OrderKey,
                         @cConsigneeKey     = @c_Consigneekey,
                         @cPrioriry         = @c_Priority,
                         @dOrderDate        = @d_OrderDate,
                         @dDelivery_Date    = @d_Delivery_Date,
                         @cOrderType        = @c_OrderType,
                         @cDoor             = @c_Door,
                         @cRoute            = @c_Route,
                         @cDeliveryPlace    = @c_DeliveryPlace,
                         @nStdGrossWgt      = @n_totweight,
                         @nStdCube          = @n_totcube,
                         @cExternOrderKey   = @c_ExternOrderKey,
                         @cCustomerName     = @c_C_Company,
                         @nTotOrderLines    = @n_TotOrdLine,
                         @nNoOfCartons      = 0,
                         @cOrderStatus      = @c_OrderStatus,
                         @b_Success         = @b_Success OUTPUT,
                         @n_err             = @n_err     OUTPUT,
                         @c_errmsg          = @c_errmsg  OUTPUT
              
                    SELECT @n_err = @@ERROR
              
                    IF @n_err <> 0
                    BEGIN
                       SELECT @n_continue = 3
                       SELECT @n_err = 63540
                       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into LOADPLANDETAIL Failed. (ispWAVLP06)"
                    END
                 END
                 
                 DELETE FROM #TMP_ORDER WHERE RowID = @n_RowID  --NJOW02
                 
                 --SET @c_PrevBuyerPO = @c_BuyerPO
              
                 --FETCH NEXT FROM cur_loadpland INTO @c_OrderKey, @c_BuyerPO, @n_NoofChildOrders, @n_TotalChildQty
              END
              --CLOSE cur_loadpland
              --DEALLOCATE cur_loadpland            
              FETCH NEXT FROM cur_BuyerPO INTO @c_BuyerPO       
           END
           CLOSE cur_BuyerPO
           DEALLOCATE cur_BuyerPO
                                        	
           FETCH NEXT FROM cur_LPGroup INTO @c_FieldVal01, @c_FieldVal01Name            	   	
        END	
        CLOSE cur_LPGroup
        DEALLOCATE cur_LPGroup      
        	
        FETCH NEXT FROM cur_SETUP INTO @c_OrdUDF05, @c_GroupField, @c_MaxQtyPerLoad
     END
     CLOSE cur_SETUP
     DEALLOCATE cur_SETUP                 
   END 
  
   IF (@n_continue = 1 OR @n_continue = 2) AND @n_loadcount > 0 
   BEGIN
      -- Default Last Orders Flag to Y
      UPDATE ORDERS WITH (ROWLOCK)
         SET ORDERS.SectionKey = 'Y', ORDERS.TrafficCop = NULL
            ,ORDERS.EditDate   = GETDATE() 
      FROM ORDERS
      JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = ORDERS.OrderKey
      WHERE WD.WaveKey = @c_WaveKey
   END
  
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @n_loadcount > 0
         SELECT @c_errmsg = RTRIM(CAST(@n_loadcount AS CHAR)) + ' Load Plan Generated'
      ELSE
         SELECT @c_errmsg = 'No Load Plan Generated'
   END
                                
   RETURN_SP:
   
   IF @n_continue=3 -- Error Occured - Process And Return
   BEGIN
       SELECT @b_success = 0
       IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCnt
       BEGIN
           ROLLBACK TRAN
       END
       ELSE
       BEGIN
           WHILE @@TRANCOUNT > @n_StartTranCnt
           BEGIN
               COMMIT TRAN
           END
       END
       EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispWAVLP06'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
   END
   ELSE
   BEGIN
       SELECT @b_success = 1
       WHILE @@TRANCOUNT>@n_StartTranCnt
       BEGIN
           COMMIT TRAN
       END
       RETURN
   END         
END   

GO