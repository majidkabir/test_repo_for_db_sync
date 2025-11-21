SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateTOASN_NCCI                                            */
/* Creation Date: 2020-09-11                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15103 - Populate ASN Detail from ORDERS - NCCI          */
/*          Copy from ispPopulateTOASN                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: ntrMBOLHeaderUpdate                                       */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASN_NCCI] 
   @c_OrderKey NVARCHAR(10)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExternReceiptKey      NVARCHAR(20),
           @c_SKU                   NVARCHAR(20),
           @c_PackKey               NVARCHAR(10),
           @c_UOM                   NVARCHAR(5),
           @c_SKUDescr              NVARCHAR(60),
           @c_StorerKey             NVARCHAR(15),
           @c_OrderLine             NVARCHAR(5),
           @c_Facility              NVARCHAR(5),
           @c_ExternOrderLine       NVARCHAR(10)


   DECLARE @c_Lottable01            NVARCHAR(18),
           @c_Lottable02            NVARCHAR(18),
           @c_Lottable03            NVARCHAR(18),
           @d_Lottable04            DATETIME,
           @d_Lottable05            DATETIME,
           @c_Lottable06            NVARCHAR(30),
           @c_Lottable07            NVARCHAR(30),
           @c_Lottable08            NVARCHAR(30),
           @c_Lottable09            NVARCHAR(30),
           @c_Lottable10            NVARCHAR(30),
           @c_Lottable11            NVARCHAR(30),
           @c_Lottable12            NVARCHAR(30),
           @d_Lottable13            DATETIME,
           @d_Lottable14            DATETIME,
           @d_Lottable15            DATETIME,
           @n_ShippedQty            int

   DECLARE @c_NewReceiptKey         NVARCHAR(10),
           @c_ReceiptLine           NVARCHAR(5),
           @n_LineNo                int,
           @c_ConsigneeKey          NVARCHAR(15),
           @c_ToFacility            NVARCHAR(5),
           @n_ExpectedQty           int,
           @n_QtyReceived           int,
           @n_RemainExpectedQty     int,
           @c_loclast               NVARCHAR(30),
           @c_userdefine08          NVARCHAR(30) ,
           @c_userdefine07          NVARCHAR(30),
           @c_warehousereference    NVARCHAR(10)
    
   DECLARE @n_continue              int,
           @b_success               int,
           @n_err                   int,
           @c_errmsg                NVARCHAR(255),
           @c_salesofftake          NVARCHAR(1) -- Add by June 27.Mar.02
   
   DECLARE @c_SQL          NVARCHAR(MAX) = '',
           @c_FromTable    NVARCHAR(MAX) = '', 
           @c_FromCol      NVARCHAR(MAX) = '', 
           @c_ToTable      NVARCHAR(MAX) = '', 
           @c_ToCol        NVARCHAR(MAX) = '',
           @c_SQLArg       NVARCHAR(MAX) = '',
           @n_RowID        INT,
           @c_Value        NVARCHAR(MAX),
           @c_SQLSet       NVARCHAR(MAX),
           @c_ColValue     NVARCHAR(4000)

   CREATE TABLE #TMP_RECEIPTLIST (
      RowID        INT NOT NULL IDENTITY(1,1),
      ToTable      NVARCHAR(100),
      ToCol        NVARCHAR(100),
      ToValue      NVARCHAR(4000),
      FromTable    NVARCHAR(100),
      FromCol      NVARCHAR(100),
      FromValue    NVARCHAR(4000),
   )
   
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0

   IF @n_continue = 1 OR @n_continue = 2  --001
   BEGIN     
   	SELECT @c_Storerkey = Storerkey
   	FROM ORDERS (NOLOCK)
   	WHERE OrderKey = @c_OrderKey
   	    
      INSERT INTO #TMP_RECEIPTLIST (ToTable, ToCol, ToValue, FromTable, FromCol, FromValue)
      SELECT CASE WHEN CHARINDEX('.',CL.Long) > 0 THEN SUBSTRING(LTRIM(RTRIM(CL.Long)),1 , CHARINDEX('.',CL.Long) - 1) 
                                                  ELSE '' END AS ToTable,
             CASE WHEN CHARINDEX('.',CL.Long) > 0 THEN SUBSTRING(LTRIM(RTRIM(CL.Long)), CHARINDEX('.',CL.Long) + 1, LEN(CL.Long) - CHARINDEX('.',CL.Long) + 1) 
                                                  ELSE '' END AS ToCol, '',
             CASE WHEN CHARINDEX('.',CL.Notes) > 0 THEN SUBSTRING(LTRIM(RTRIM(CL.Notes)),1 , CHARINDEX('.',CL.Notes) - 1) 
                                                  ELSE '' END AS FromTable,
             CASE WHEN CHARINDEX('.',CL.Notes) > 0 THEN SUBSTRING(LTRIM(RTRIM(CL.Notes)), CHARINDEX('.',CL.Notes) + 1, LEN(CL.Notes) - CHARINDEX('.',CL.Notes) + 1) 
                                                  ELSE '' END AS FromCol,''
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'AutoASN'
      AND (SUBSTRING(LTRIM(RTRIM(CL.Long)),1 , CHARINDEX('.',CL.Long) - 1) IN ('RECEIPT','RECEIPTDETAIL') OR 
      SUBSTRING(LTRIM(RTRIM(CL.Notes)),1 , CHARINDEX('.',CL.Notes) - 1) IN ('ORDERS','ORDERDETAIL') )
      AND CL.Storerkey = @c_Storerkey
      
      DECLARE CUR_LOOPHEADER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowID, FromTable, FromCol, ToTable, ToCol
      FROM #TMP_RECEIPTLIST
      WHERE ToTable = 'RECEIPT' AND FromTable IN ('ORDERS','ORDERDETAIL')
      ORDER BY RowID
      
      OPEN CUR_LOOPHEADER
      	
      FETCH NEXT FROM CUR_LOOPHEADER INTO @n_RowID
                                        , @c_FromTable 
                                        , @c_FromCol   
                                        , @c_ToTable   
                                        , @c_ToCol    
                                  
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      	SET @c_SQL = 'SELECT @c_ColValue = ' + @c_FromTable + '.' + @c_FromCol + ' ' + CHAR(13) +
      	             'FROM ORDERS (NOLOCK) ' + CHAR(13) +
                      'JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey' + CHAR(13) +
                      'WHERE ORDERS.Orderkey = @c_OrderKey'
      	                 
         SET @c_SQLArg = N'@c_ColValue NVARCHAR(MAX) OUTPUT, @c_Orderkey NVARCHAR(10) '
      
         EXEC sp_executesql @c_SQL, @c_SQLArg, @c_ColValue OUTPUT, @c_Orderkey 
         
         SET @c_SQL = N'UPDATE #TMP_RECEIPTLIST ' + CHAR(13) + 
                       'SET ToValue = @c_ColValue, FromValue = @c_ColValue ' + CHAR(13) + 
                       'WHERE RowID = @n_RowID '
                       
         SET @c_SQLArg = N'@c_NewReceiptKey NVARCHAR(10), @n_RowID INT, @c_ColValue NVARCHAR(MAX) '
      
         EXEC sp_executesql @c_SQL, @c_SQLArg, @c_NewReceiptKey, @n_RowID, @c_ColValue
        
         FETCH NEXT FROM CUR_LOOPHEADER INTO @n_RowID
                                           , @c_FromTable 
                                           , @c_FromCol   
                                           , @c_ToTable   
                                           , @c_ToCol       
      END 
      CLOSE CUR_LOOPHEADER
      DEALLOCATE CUR_LOOPHEADER
   END

   -- insert into Receipt Header
   IF @n_continue = 1 OR @n_continue = 2  --001
   BEGIN         
      SELECT @c_ConsigneeKey = ORDERS.ConsigneeKey,
             @c_StorerKey = ORDERS.Storerkey,  
             @c_ExternReceiptKey = ORDERS.ExternOrderkey,
             @c_WarehouseReference = ORDERS.Orderkey,
             @c_ExternOrderLine = ORDERDETAIL.Orderlinenumber,
             @c_facility = ORDERS.Facility     
      FROM   ORDERS (NOLOCK)
      JOIN   MBOL (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      JOIN   ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE  ORDERS.OrderKey = @c_OrderKey

  IF @n_continue = 1 OR @n_continue = 2
   BEGIN
     SELECT @c_loclast = Userdefine01,
            @c_userdefine08 = Userdefine08,
            @c_userdefine07 = userdefine07
     FROM FACILITY (NOLOCK)
     WHERE Facility = @c_Facility
   END
  
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN         
      IF dbo.fnc_RTrim(@c_StorerKey) IS NOT NULL
      BEGIN
         -- get next receipt key
         SELECT @b_success = 0
         EXECUTE   nspg_getkey
         "RECEIPT"
         , 10
         , @c_NewReceiptKey OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
         
         IF @b_success = 1
         BEGIN
            INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, WarehouseReference, StorerKey, RecType, Facility, appointment_no, DOCTYPE)
            VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_warehousereference, @c_StorerKey, 'TF', @c_userdefine08,@c_facility, 'A')
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate Receipt Key Failed! (ispPopulateTRO2ASN)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END

         --Update Receipt Column from Codelkup
         DECLARE CUR_LOOPHEADER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowID, FromTable, FromCol, ToTable, ToCol, ToValue
         FROM #TMP_RECEIPTLIST
         WHERE ToTable = 'RECEIPT' AND FromTable IN ('ORDERS','ORDERDETAIL')
         ORDER BY RowID
         
         OPEN CUR_LOOPHEADER
         	
         FETCH NEXT FROM CUR_LOOPHEADER INTO @n_RowID
                                           , @c_FromTable 
                                           , @c_FromCol   
                                           , @c_ToTable   
                                           , @c_ToCol   
                                           , @c_Value
                                     
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF ISNULL(@c_SQLSet,'') = ''
            BEGIN
            	SET @c_SQLSet = N'UPDATE RECEIPT ' + CHAR(13) +
                                'SET ' + @c_ToCol + ' = ''' + @c_Value + '''' + CHAR(13) +
                                ', TrafficCop = NULL, EditWho = SUSER_SNAME(), EditDate = GETDATE() '+ CHAR(13)
            END
            ELSE
            BEGIN
               SET @c_SQLSet = @c_SQLSet + CHAR(13) +', ' + @c_ToCol + ' = ''' + @c_Value + '''' + CHAR(13)
            END
         
            FETCH NEXT FROM CUR_LOOPHEADER INTO @n_RowID
                                              , @c_FromTable 
                                              , @c_FromCol   
                                              , @c_ToTable   
                                              , @c_ToCol
                                              , @c_Value       
         END 
         CLOSE CUR_LOOPHEADER
         DEALLOCATE CUR_LOOPHEADER
         
         IF ISNULL(@c_SQLSet,'') <> ''
         BEGIN
         	SET @c_SQLSet = @c_SQLSet + 'WHERE ReceiptKey = @c_NewReceiptKey'
            SET @c_SQLArg = N'@c_NewReceiptKey NVARCHAR(10)'
            EXEC sp_executesql @c_SQLSet, @c_SQLArg, @c_NewReceiptKey
         END
          
         SET @c_SQLSet = ''
      END    
      ELSE
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Storer Key is BLANK! (ispPopulateTRO2ASN)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END -- if continue = 1 or 2

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN         
      SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1
      SELECT @c_ExternOrderLine = SPACE(5)

      WHILE 1=1
      BEGIN
         SET ROWCOUNT 1
      
         SELECT @c_SKU        = ORDERDETAIL.Sku,   
                @c_PackKey    = ORDERDETAIL.PackKey,   
                @c_UOM        = ORDERDETAIL.UOM,   
                @n_ShippedQty = (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY),
                @c_SKUDescr   = SKU.DESCR,   
                @c_OrderLine  = ORDERDETAIL.OrderLineNumber,
                @c_ExternOrderLine = ORDERDETAIL.ExternLineNo
         FROM ORDERDETAIL (NOLOCK)
         JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) 
         JOIN SKU  (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku ) 
         WHERE ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 ) AND  
               ( ORDERDETAIL.OrderKey = @c_orderkey ) AND             
               ( ORDERDETAIL.ExternLineNo > @c_ExternOrderLine )
         ORDER by ORDERDETAIL.ExternLineNo
         IF @@ROWCOUNT = 0
            BREAK

         SET ROWCOUNT 0      
         IF dbo.fnc_RTrim(@c_OrderKey) IS NOT NULL AND 
            dbo.fnc_RTrim(@c_OrderLine) IS NOT NULL 
         BEGIN
         	DECLARE CUR_LOOPDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowID, FromTable, FromCol, ToTable, ToCol
            FROM #TMP_RECEIPTLIST
            WHERE ToTable = 'RECEIPTDETAIL' AND FromTable IN ('ORDERS','ORDERDETAIL')
            ORDER BY RowID
            
            OPEN CUR_LOOPDETAIL
            	
            FETCH NEXT FROM CUR_LOOPDETAIL INTO @n_RowID
                                              , @c_FromTable 
                                              , @c_FromCol   
                                              , @c_ToTable   
                                              , @c_ToCol 
                                        
            WHILE @@FETCH_STATUS <> -1
            BEGIN
            	SET @c_SQL = 'SELECT @c_ColValue = ' + @c_FromTable + '.' + @c_FromCol + ' ' + CHAR(13) +
                            'FROM ORDERS (NOLOCK) ' + CHAR(13) +
                            'JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey' + CHAR(13) +
                            'WHERE ORDERDETAIL.Orderkey = @c_OrderKey AND ORDERDETAIL.ExternLineNo = @c_ExternOrderLine'
            	                 
               SET @c_SQLArg = N'@c_ColValue NVARCHAR(MAX) OUTPUT, @c_Orderkey NVARCHAR(10), @c_ExternOrderLine NVARCHAR(10) '
            
               EXEC sp_executesql @c_SQL, @c_SQLArg, @c_ColValue OUTPUT, @c_Orderkey, @c_ExternOrderLine
               
               SET @c_SQL = N'UPDATE #TMP_RECEIPTLIST ' + CHAR(13) + 
                             'SET ToValue = @c_ColValue, FromValue = @c_ColValue ' + CHAR(13) + 
                             'WHERE RowID = @n_RowID '
                             
               SET @c_SQLArg = N'@c_NewReceiptKey NVARCHAR(10), @n_RowID INT, @c_ColValue NVARCHAR(MAX) '
            
               EXEC sp_executesql @c_SQL, @c_SQLArg, @c_NewReceiptKey, @n_RowID, @c_ColValue
            
            	FETCH NEXT FROM CUR_LOOPDETAIL INTO @n_RowID
                                                 , @c_FromTable 
                                                 , @c_FromCol   
                                                 , @c_ToTable   
                                                 , @c_ToCol    
            END 
            CLOSE CUR_LOOPDETAIL
            DEALLOCATE CUR_LOOPDETAIL
            
              DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
                  SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,
                     LOTATTRIBUTE.Lottable01,
                     LOTATTRIBUTE.Lottable02,
                     LOTATTRIBUTE.Lottable03,
                     LOTATTRIBUTE.Lottable04,
                     LOTATTRIBUTE.Lottable05,
                     ISNULL(LOTATTRIBUTE.Lottable06,''),
                     ISNULL(LOTATTRIBUTE.Lottable07,''),
                     ISNULL(LOTATTRIBUTE.Lottable08,''),
                     ISNULL(LOTATTRIBUTE.Lottable09,''),
                     ISNULL(LOTATTRIBUTE.Lottable10,''),
                     ISNULL(LOTATTRIBUTE.Lottable11,''),
                     ISNULL(LOTATTRIBUTE.Lottable12,''),
                     LOTATTRIBUTE.Lottable13,
                     LOTATTRIBUTE.Lottable14,
                     LOTATTRIBUTE.Lottable15
                  FROM PICKDETAIL (NOLOCK) 
                  JOIN LotAttribute (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
                  WHERE (PICKDETAIL.OrderKey = @c_OrderKey AND
                         PICKDETAIL.OrderLineNumber = @c_OrderLine)
                  GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                           LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,
                           LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                           LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15

               OPEN PICK_CUR
               
               FETCH NEXT FROM PICK_CUR
                  INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                       @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                       @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
      
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SELECT @c_ReceiptLine = RIGHT( '0000' + dbo.fnc_RTrim(CAST(@n_LineNo AS NVARCHAR(5))), 5)
   
                  -- select @n_RemainExpectedQty '@n_RemainExpectedQty', @n_QtyReceived '@n_QtyReceived',
                  --       @c_ExternPOKey '@c_ExternPOKey' 
                  IF @n_QtyReceived IS NULL
                     SELECT @n_QtyReceived = 0                      
   
                  INSERT INTO RECEIPTDETAIL (ReceiptKey,          ReceiptLineNumber,   ExternReceiptKey, 
                                             ExternLineNo,        StorerKey,           SKU, 
                                             QtyExpected,         QtyReceived,
                                             UOM,                 PackKey,             ToLoc,
                                             Lottable01,          Lottable02,          Lottable03,       Lottable04,       Lottable05,
                                             Lottable06,          Lottable07,          Lottable08,       Lottable09,       Lottable10,
                                             Lottable11,          Lottable12,          Lottable13,       Lottable14,       Lottable15,
                                             BeforeReceivedQty)
                              VALUES        (@c_NewReceiptKey,    @c_ReceiptLine,      @c_ExternReceiptKey,
                                             @c_OrderLine,        @c_StorerKey,        @c_SKU,
                                             ISNULL(@n_QtyReceived,0),   0,               
                                             @c_UOM,              @c_Packkey,          @c_loclast,
                                             @c_Lottable01,       @c_Lottable02,       @c_Lottable03,    @d_Lottable04,    @d_Lottable05, 
                                             @c_Lottable06,       @c_Lottable07,       @c_Lottable08,    @c_Lottable09,    @c_Lottable10,
                                             @c_Lottable11,       @c_Lottable12,       @d_Lottable13,    @d_Lottable14,    @d_Lottable15,
                                             0)
                                             
   
                  SELECT @n_LineNo = @n_LineNo + 1
                  
                  --Update ReceiptDetail Column from Codelkup
                  DECLARE CUR_LOOPDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT RowID, FromTable, FromCol, ToTable, ToCol, ToValue
                  FROM #TMP_RECEIPTLIST
                  WHERE ToTable = 'RECEIPTDETAIL' AND FromTable IN ('ORDERS','ORDERDETAIL')
                  ORDER BY RowID
            
                  OPEN CUR_LOOPDETAIL
            	
                  FETCH NEXT FROM CUR_LOOPDETAIL INTO @n_RowID
                                                    , @c_FromTable 
                                                    , @c_FromCol   
                                                    , @c_ToTable   
                                                    , @c_ToCol 
                                                    , @c_Value
                                        
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
            	      IF ISNULL(@c_SQLSet,'') = ''
                     BEGIN
               	      SET @c_SQLSet = N'UPDATE RECEIPTDETAIL ' + CHAR(13) +
                                         'SET ' + @c_ToCol + ' = ''' + @c_Value + '''' + CHAR(13) +
                                         ', TrafficCop = NULL, EditWho = SUSER_SNAME(), EditDate = GETDATE() '+ CHAR(13)
                     END
                     ELSE
                     BEGIN
                        SET @c_SQLSet = @c_SQLSet + CHAR(13) +', ' + @c_ToCol + ' = ''' + @c_Value + '''' + CHAR(13)
                     END
                     
            	      FETCH NEXT FROM CUR_LOOPDETAIL INTO @n_RowID
                                                       , @c_FromTable 
                                                       , @c_FromCol   
                                                       , @c_ToTable   
                                                       , @c_ToCol 
                                                       , @c_Value   
                  END 
                  CLOSE CUR_LOOPDETAIL
                  DEALLOCATE CUR_LOOPDETAIL

                  IF ISNULL(@c_SQLSet,'') <> ''
                  BEGIN
                     SET @c_SQLSet = @c_SQLSet + 'WHERE ReceiptKey = @c_NewReceiptkey AND ReceiptLineNumber = @c_ReceiptLine'
                     SET @c_SQLArg = N'@c_NewReceiptkey NVARCHAR(10), @c_ReceiptLine NVARCHAR(10)'
                     EXEC sp_executesql @c_SQLSet, @c_SQLArg, @c_NewReceiptkey, @c_ReceiptLine
                  END
          
                  SET @c_SQLSet = ''
   
                  FETCH NEXT FROM PICK_CUR
                     INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                          @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
               END -- WHILE @@FETCH_STATUS <> -1
               DEALLOCATE PICK_CUR
            END

            ----Update ReceiptDetail Column from Codelkup
            --DECLARE CUR_LOOPDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            --SELECT RowID, FromTable, FromCol, ToTable, ToCol, ToValue
            --FROM #TMP_RECEIPTLIST
            --WHERE ToTable = 'RECEIPTDETAIL' AND FromTable IN ('ORDERS','ORDERDETAIL')
            --ORDER BY RowID
            
            --OPEN CUR_LOOPDETAIL
            	
            --FETCH NEXT FROM CUR_LOOPDETAIL INTO @n_RowID
            --                                  , @c_FromTable 
            --                                  , @c_FromCol   
            --                                  , @c_ToTable   
            --                                  , @c_ToCol 
            --                                  , @c_Value
                                        
            --WHILE @@FETCH_STATUS <> -1
            --BEGIN
            --	IF ISNULL(@c_SQLSet,'') = ''
            --   BEGIN
            --   	SET @c_SQLSet = N'UPDATE RECEIPTDETAIL ' + CHAR(13) +
            --                       'SET ' + @c_ToCol + ' = ''' + @c_Value + '''' + CHAR(13) +
            --                       ', TrafficCop = NULL, EditWho = SUSER_SNAME(), EditDate = GETDATE() '+ CHAR(13)
            --   END
            --   ELSE
            --   BEGIN
            --      SET @c_SQLSet = @c_SQLSet + CHAR(13) +', ' + @c_ToCol + ' = ''' + @c_Value + '''' + CHAR(13)
            --   END
                     
            --	FETCH NEXT FROM CUR_LOOPDETAIL INTO @n_RowID
            --                                     , @c_FromTable 
            --                                     , @c_FromCol   
            --                                     , @c_ToTable   
            --                                     , @c_ToCol 
            --                                     , @c_Value   
            --END 
            --CLOSE CUR_LOOPDETAIL
            --DEALLOCATE CUR_LOOPDETAIL

            --IF ISNULL(@c_SQLSet,'') <> ''
            --BEGIN
            --   SET @c_SQLSet = @c_SQLSet + 'WHERE ReceiptKey = @c_NewReceiptkey AND ReceiptLineNumber = @c_ReceiptLine'
            --   SET @c_SQLArg = N'@c_NewReceiptkey NVARCHAR(10), @c_ReceiptLine NVARCHAR(10)'
            --   EXEC sp_executesql @c_SQLSet, @c_SQLArg, @c_NewReceiptkey, @c_ReceiptLine
            --END
          
            --SET @c_SQLSet = ''

         END
      END -- WHILE
      SET ROWCOUNT 0
   END -- if continue = 1 or 2 001

GO