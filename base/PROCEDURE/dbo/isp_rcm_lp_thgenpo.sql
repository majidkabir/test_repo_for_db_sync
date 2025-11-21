SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_LP_THGenPO                                 */
/* Creation Date: 14-Jan-2016                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 372359-TH-MFG Auto generate PO from Store Order             */
/*                                                                      */
/* Called By: Load Plan Dymaic RCM configure at listname 'RCMConfig'    */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_RCM_LP_THGenPO]
   @c_Loadkey NVARCHAR(10),   
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN 
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

-->PO:
--Sellername = Vender(Listname.VRATIO.UDF02)
--Userdefine01 = Orders.Userdefine01 (Brand)
--Userdefine03 = Loadkey
--Externpokey = 'PO' + Orders.Userdefine01(Brand) + DDMMYYY + Running no
-->PODetail:
--Lottable01 = Loadkey
--Lottable02 = Orders.Externorderkey
--Lottable03 = Externpokey
--Userdefine04 = Orders.Consigneekey
--Userdefine10 = Orders.Orderkey
--ExternlineNo = Orderdetail.OrderLineNumber

-->Receipt:
--Loadkey = Loadkey after finalize
-->Receiptdetail:
--Lottable01 = Loadkey
--Lottable02 = Orders.Externorderkey
--Lottable03 = PO.Externpokey
--Userdefine04 = Orders.Consigneekey
--Userdefine10 = Orders.Orderkey
--POkey = PO.Pokey
--ExternPOkey = PO.ExternPOkey

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int
           
   DECLARE @c_Facility        NVARCHAR(5),
           @c_storerkey       NVARCHAR(15),
           @c_Sku             NVARCHAR(20),
           @c_Orderkey        NVARCHAR(10),
           @n_OrderQty        INT,
           @c_Vender          NVARCHAR(30),
           @c_SkuGroup        NVARCHAR(10),
           @c_Class           NVARCHAR(10),
           @c_POkey           NVARCHAR(10),
           @c_Userdefine01    NVARCHAR(20),
           @c_Userdefine09    NVARCHAR(10),  -- orders.userdefine01(Brand)
           @c_ExternPOkey     NVARCHAR(20),
           @c_RunningNo       NVARCHAR(2),
           @n_LineNo          INT,
           @c_POLineNumber    NVARCHAR(5),
           @c_ExternOrderkey  NVARCHAR(50),  --tlting_ext
           @c_SKUDescr        NVARCHAR(60),
           @n_POQty           INT, 
           @c_UOM             NVARCHAR(10),
           @c_Packkey         NVARCHAR(10),
           @c_Lottable01      NVARCHAR(18),
           @c_Lottable02      NVARCHAR(18),
           @c_Lottable03      NVARCHAR(18),
           @c_Consigneekey    NVARCHAR(15),
           @dt_deliverydate   DATETIME,
           @c_ExternLineNo    NVARCHAR(20)
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   SELECT TOP 1 @c_Facility = Facility,
                @c_Storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE Loadkey = @c_Loadkey    
   
   --Validation
   IF @n_continue IN (1,2)
   BEGIN      	
   	  IF EXISTS (SELECT 1 
   	             FROM CODELKUP (NOLOCK)
   	             WHERE Listname = 'VRATIO'
   	             AND (ISNULL(UDF01,'') = '' --sku
   	                  OR ISNULL(UDF02,'') = ''  --vender
   	                  OR ISNULL(UDF03,'') = '')) --ratio
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Sku(UDF01) or Vender(UDF02) or Ratio(UDF03) cannot be blank at listname VRATIO. (isp_RCM_LP_THGen)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO ENDPROC
      END             
   	
      SELECT TOP 1 @c_Sku = CL.UDF01 
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.Listname = 'VRATIO'
      GROUP BY CL.Storerkey, CL.UDF01
      HAVING SUM( CASE WHEN ISNUMERIC(CL.UDF03) = 1 THEN CAST(CL.UDF03 AS DECIMAL(8,2)) ELSE 0 END ) <> 100
      
      IF ISNULL(@c_Sku,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Vendor Ratio Setup for Sku ''' + RTRIM(@c_Sku) + '''. Must Be 100 Percent. (isp_RCM_LP_THGen)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO ENDPROC
      END
      
      IF EXISTS(SELECT 1 
                FROM PO (NOLOCK)
                WHERE Userdefine03 = @c_Loadkey
                AND Storerkey = @c_Storerkey)     
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PO Already Exists for this load plan. Not allow to Re-Generate. (isp_RCM_LP_THGen)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO ENDPROC
      END                      

      SET @c_Sku = ''
      SELECT TOP 1 @c_sku = OD.Sku      
      FROM ORDERS O (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      LEFT JOIN CODELKUP CL (NOLOCK) ON OD.Storerkey = CL.Storerkey AND OD.Sku = CL.UDF01
      WHERE O.Loadkey = @c_loadkey
      AND CL.Code IS NULL

      IF ISNULL(@c_sku,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No Vender Ratio Setup for Sku ''' + RTRIM(@c_Sku) + '''. (isp_RCM_LP_THGen)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO ENDPROC
      END                                     
   END              

   --Prepare reference table
   IF @n_continue IN (1,2)
   BEGIN   	
   	  CREATE TABLE #TMP_PODETAIL (Orderkey NVARCHAR(10) NULL,
   	                              Storerkey NVARCHAR(15) NULL,
   	                              Sku NVARCHAR(20) NULL,   	                                 	                              
   	                              Vender NVARCHAR(30) NULL,
   	                              POQty INT NULL,
   	                              UOM NVARCHAR(10) NULL,
   	                              ExternLineNo NVARCHAR(20) NULL)
   	
   	  --Calculate qty by sku
   	  SELECT OD.Storerkey, OD.Sku, SUM(OD.OriginalQty) AS Qty
   	  INTO #TMP_SKUQTY
   	  FROM ORDERS O (NOLOCK) 
   	  JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
   	  WHERE O.Loadkey = @c_Loadkey
   	  AND OD.OriginalQty > 0
   	  GROUP BY OD.Storerkey, OD.Sku
   	  
   	  --Calculate sku's vender qty by ratio
   	  --UDF01=SKU, UDF02=VENDER UDF03=RATIO
   	  SELECT TS.Storerkey, TS.Sku, CL.UDF02 AS Vender, CEILING((TS.Qty * CAST(CL.UDF03 AS DECIMAL(8,2))) / 100) AS POQty
   	  INTO #TMP_VENDERQTY
   	  FROM CODELKUP CL (NOLOCK)
   	  JOIN #TMP_SKUQTY TS ON CL.Storerkey = TS.Storerkey AND CL.UDF01 = TS.Sku
   	  WHERE CL.Listname = 'VRATIO'
   	  AND ISNUMERIC(CL.UDF03) = 1 AND CL.UDF03 NOT IN('0','')
   END
   
   --Determine order Vender by Vender Qty
   IF @n_continue IN (1,2)
   BEGIN
      DECLARE CUR_ORDERDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
        SELECT OD.Orderkey, OD.Storerkey, OD.Sku, SUM(OD.OriginalQty), MIN(OD.UOM), MIN(OD.ExternLineNo)
        FROM ORDERS O (NOLOCK)
        JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
        JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.sku
        WHERE O.Loadkey = @c_Loadkey
        AND OD.OriginalQty > 0
        GROUP BY OD.Orderkey, OD.Storerkey, OD.Sku
        ORDER BY OD.Sku, SUM(OD.OriginalQty)
        
      OPEN CUR_ORDERDETAIL  
      FETCH NEXT FROM CUR_ORDERDETAIL INTO @c_Orderkey, @c_Storerkey, @c_Sku, @n_OrderQty, @c_UOM, @c_ExternLineNo

      WHILE @@FETCH_STATUS = 0  
      BEGIN           	         
      	 SET @c_Vender = ''
      	 --find the best fit vender per order's sku qty
      	 SELECT TOP 1 @c_Vender = Vender
      	 FROM #TMP_VENDERQTY 
      	 WHERE Storerkey = @c_Storerkey
      	 AND Sku = @c_Sku
      	 AND POQty >= @n_OrderQty
      	 ORDER BY POQty
      	 
      	 --if best fit not found get the vender with larger po qty
      	 IF ISNULL(@c_Vender,'') = ''
      	 BEGIN
      	    SELECT TOP 1 @c_Vender = Vender
      	    FROM #TMP_VENDERQTY 
      	    WHERE Storerkey = @c_Storerkey
      	    AND Sku = @c_Sku
      	    ORDER BY POQty DESC
      	 END
      	 
      	 IF ISNULL(@c_Vender,'') = ''
      	 BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No Available Vender found for Sku ''' + RTRIM(@c_Sku) + '''. (isp_RCM_LP_THGen)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
           GOTO ENDPROC
      	 END
      	 
      	 UPDATE #TMP_VENDERQTY 
      	 SET POQty = POQty - @n_OrderQty
      	 WHERE Storerkey = @c_Storerkey
      	 AND Sku = @c_Sku
      	 AND Vender = @c_Vender
      	 
      	 INSERT INTO #TMP_PODETAIL (Orderkey, Storerkey, Sku, Vender, POQty, UOM, ExternLineNo)
      	 VALUES (@c_Orderkey, @c_Storerkey, @c_Sku, @c_Vender, @n_OrderQty, @c_UOM, @c_ExternLineNo)      	 
      
         FETCH NEXT FROM CUR_ORDERDETAIL INTO @c_Orderkey, @c_Storerkey, @c_Sku, @n_OrderQty, @c_UOM, @c_ExternLineNo
      END
      CLOSE CUR_ORDERDETAIL  
      DEALLOCATE CUR_ORDERDETAIL                                              	  
   END
   
   --Create PO by vender, susr1, skugroup, class
   IF @n_continue IN (1,2)
   BEGIN
      DECLARE CUR_PO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT POD.Vender, ISNULL(O.Userdefine01,''), ISNULL(SKU.SkuGroup,''), ISNULL(SKU.Class,'')
         FROM #TMP_PODETAIL POD   
         JOIN ORDERS O (NOLOCK) ON POD.Orderkey = O.Orderkey      
         JOIN SKU (NOLOCK) ON POD.Storerkey = SKU.Storerkey AND POD.Sku = SKU.Sku
         
      OPEN CUR_PO  
      FETCH NEXT FROM CUR_PO INTO @c_Vender, @c_Userdefine01, @c_SkuGroup, @c_Class

      WHILE @@FETCH_STATUS = 0  
      BEGIN           	        
      	 --Create New PO            
      	 IF @n_continue IN (1,2)
      	 BEGIN      	 	
            SELECT @b_success = 0
            EXECUTE nspg_getkey
            'PO'
            , 10
            , @c_POKey OUTPUT
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT
            
            IF @b_success = 1
            BEGIN
            	 SELECT @b_success = 0
               EXECUTE nspg_getkey
               'THGENPO'
               ,2
               ,@c_RunningNo OUTPUT
               ,@b_success OUTPUT
               ,@n_err OUTPUT
               ,@c_errmsg OUTPUT
               
               SET @c_ExternPOkey = 'PO' + RTRIM(@c_Userdefine01) + REPLACE(CONVERT(NVARCHAR,GETDATE(),103),'/','') + @c_RunningNo
               SET @c_Userdefine09 = '01' --promotion code for LF. fixed at orders.userdefine09
            	
               INSERT INTO PO (POKey, Externpokey, Potype, Sellername, Userdefine01, Userdefine03, Userdefine09, Storerkey)
               VALUES (@c_POKey, @c_ExternPOkey, '5', @c_Vender, @c_Userdefine01, @c_Loadkey, @c_Userdefine09, @c_Storerkey)
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate PO Key Failed. (isp_RCM_LP_THGen)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO ENDPROC
            END      	 
         END

      	 --Create PO detail      	       	 
         DECLARE CUR_PODETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT POD.Orderkey, O.ExternOrderkey, POD.Storerkey, POD.Sku, SKU.Descr, SUM(POD.POQty),
                   SKU.Packkey, POD.UOM, O.Consigneekey, O.DeliveryDate, POD.ExternLineNo
            FROM #TMP_PODETAIL POD
            JOIN SKU (NOLOCK) ON POD.Storerkey = SKU.Storerkey AND POD.Sku = SKU.Sku
            JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
            JOIN ORDERS O (NOLOCK) ON POD.Orderkey = O.Orderkey
            WHERE POD.Vender = @c_Vender
            AND ISNULL(O.Userdefine01,'') = @c_Userdefine01 --Brand
            AND ISNULL(SKU.SkuGroup,'') = @c_SkuGroup
            AND ISNULL(SKU.Class,'') = @c_Class
            GROUP BY POD.Orderkey, O.ExternOrderkey, POD.Storerkey, POD.Sku, SKU.Descr, SKU.Packkey, POD.UOM, O.Consigneekey, O.DeliveryDate, POD.ExternLineNo

         SET @n_LineNo = 1
         
         OPEN CUR_PODETAIL  
         FETCH NEXT FROM CUR_PODETAIL INTO @c_Orderkey, @c_ExternOrderkey, @c_Storerkey, @c_Sku, @c_SkuDescr, 
                                           @n_POQty, @c_Packkey, @c_UOM, @c_Consigneekey, @dt_deliverydate, @c_ExternLineNo
         
         WHILE @@FETCH_STATUS = 0  
         BEGIN         
         	
            SELECT @c_POLineNumber = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS Char(5))), 5)
            
            SET @c_Lottable01 = @c_Loadkey
            SET @c_Lottable02 = @c_ExternOrderkey    
            SET @c_Lottable03 = @c_ExternPOKey        

	          INSERT INTO PODETAIL      (POKey,                     POLineNumber,              SKUDescription,
	                                     ExternLineNo,              StorerKey,                 SKU,
	                                     QtyOrdered,                Facility,									 ExternPOKey,
	                                     UOM,                       PackKey,									 ToID,
	                                     Lottable01,                Lottable02,                Lottable03,
	                                     Userdefine04,							Userdefine07,							 Userdefine10)
	                      VALUES        (@c_POKey,          				@c_POLineNumber,           @c_SKUDescr,
	                                     @c_ExternLineNo, 	    	  @c_StorerKey,              @c_SKU,
	                                     @n_POQty,		 	            @c_facility,							 @c_ExternPOKey,
	                                     @c_UOM,                    @c_Packkey,                '',
	                                     @c_Lottable01,             @c_Lottable02,             @c_Lottable03,
	                                     @c_Consigneekey,						@dt_DeliveryDate,					 @c_Orderkey)

	          SELECT @n_LineNo = @n_LineNo + 1
         	
            FETCH NEXT FROM CUR_PODETAIL INTO @c_Orderkey, @c_ExternOrderkey, @c_Storerkey, @c_Sku, @c_SkuDescr, 
                                              @n_POQty , @c_Packkey, @c_UOM, @c_Consigneekey, @dt_deliverydate, @c_ExternLineNo 
         END  	        
         CLOSE CUR_PODETAIL  
         DEALLOCATE CUR_PODETAIL                                              	              	   	
      	       	  
         FETCH NEXT FROM CUR_PO INTO @c_Vender, @c_Userdefine01, @c_SkuGroup, @c_Class
      END
      CLOSE CUR_PO  
      DEALLOCATE CUR_PO                                              	              	   	
   END
     
ENDPROC: 
 
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_ORDERDETAIL')) >=0 
   BEGIN
      CLOSE CUR_ORDERDETAIL           
      DEALLOCATE CUR_ORDERDETAIL      
   END  
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_PO')) >=0 
   BEGIN
      CLOSE CUR_PO           
      DEALLOCATE CUR_PO      
   END  
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_PODETAIL')) >=0 
   BEGIN
      CLOSE CUR_PODETAIL           
      DEALLOCATE CUR_PODETAIL      
   END  

   IF @n_continue=3  -- Error Occured - Process And Return
	 BEGIN
	    SELECT @b_success = 0
	    IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
	    BEGIN
	       ROLLBACK TRAN
	    END
	 ELSE
	    BEGIN
	       WHILE @@TRANCOUNT > @n_starttcnt
 	      BEGIN
	          COMMIT TRAN
	       END
	    END
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_LP_THGenPO'
	    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
	 END
	 ELSE
	    BEGIN
	       SELECT @b_success = 1
	       WHILE @@TRANCOUNT > @n_starttcnt
	       BEGIN
	          COMMIT TRAN
	       END
	       RETURN
	    END	   
END -- End PROC

GO