SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nsp_DispatchLabelFW                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Print the Dispatch Label                                   */
/* Input Parameters:  Wavekey                                           */
/*                                                                      */
/* Output Parameters: None                                              */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: Call from d_dw_dispatch_label_footwear                    */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 07-Aug-2005  YokeBeen   Allow NULL value for Temp Table's fields.    */
/*                         - (SOS#10993) - (YokeBeen01).                */
/* 13-Jun-2005  YokeBeen   NSC Project - (SOS#34678) - (YokeBeen02).    */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nsp_DispatchLabelFW] (@c_wavekey NVARCHAR(10))
 AS

 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
    DECLARE @n_continue	    int,
 		      @c_errmsg 	    NVARCHAR(255),
      		@b_success	    int,
 		      @n_err	  	    int,
    	      @n_starttcnt int,
	    	   @c_loopcnt int,
            @n_cartonno int,
            @c_orderkey NVARCHAR(10),
            @n_labelcnt int,
            @n_label int,
            @c_barcodeno NVARCHAR(10),
            @n_mod int,
            @n_qty int,
            @n_totalctn int
 

     SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

     CREATE TABLE #TEMP_ORD
			-- (YokeBeen01) - Start
       ( OrderKey         NVARCHAR(10) NULL,
			ExternOrderkey   NVARCHAR(50) NULL,   --tlting_ext
 			Company          NVARCHAR(45) NULL,
			-- (YokeBeen01) - End
--  			C_Address1        NVARCHAR(45) NULL,	-- (YokeBeen02)
 			Address2         NVARCHAR(45) NULL,
 			Address3         NVARCHAR(45) NULL,
			Address4			  NVARCHAR(45) NULL,
			City    	  		  NVARCHAR(45) NULL,		-- (YokeBeen02)
         Route				  NVARCHAR(10) NULL
         )

     CREATE TABLE #TEMP_SKU
       ( OrderKey         NVARCHAR(10),
         SumQtyAlloc      int
        )

     CREATE TABLE #TEMP_RESULT
       ( Orderkey     NVARCHAR(10),
         Cartonno     int,
         Barcodeno    NVARCHAR(10)
        )

     INSERT INTO #TEMP_ORD
     SELECT ORDERS.Orderkey,
            ExternOrderkey,
            C_Company,
--             C_Address1,		-- (YokeBeen02)
            C_Address2,
            C_Address3,
            C_Address4,
            C_City,				-- (YokeBeen02)
            Route
     FROM ORDERS (NOLOCK) 
     JOIN WAVEDETAIL (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey AND 
                                  ORDERS.UserDefine08 = 'Y' )
     WHERE WAVEDETAIL.Wavekey = @c_wavekey

     INSERT INTO #TEMP_SKU
     SELECT ORDERDETAIL.Orderkey,
            SUM(QtyAllocated+QtyPicked+ShippedQty)
     FROM ORDERDETAIL (NOLOCK)
     JOIN WAVEDETAIL (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERDETAIL.Orderkey)
     JOIN SKU (NOLOCK) ON (SKU.Sku = ORDERDETAIL.Sku AND SKU.Skugroup = 'FOOTWEAR' AND
                           SKU.Storerkey = ORDERDETAIL.Storerkey )
     WHERE WAVEDETAIL.Wavekey = @c_wavekey
     GROUP BY ORDERDETAIL.Orderkey

     SELECT @c_orderkey = ''
     WHILE(1=1)
     BEGIN
      SELECT @c_orderkey = MIN(orderkey)
      FROM  #TEMP_SKU 
      WHERE Orderkey > @c_orderkey
      
      IF @@rowcount = 0 OR @c_orderkey IS NULL BREAK

      SELECT @n_labelcnt = 0, @n_cartonno = 1
      
      SELECT @n_qty = SumQtyAlloc
      FROM #TEMP_SKU
      WHERE Orderkey = @c_orderkey
      
      SELECT @n_mod = (@n_qty % 5)
      
      IF @n_mod = 0
      BEGIN 
       SELECT @n_label = (@n_qty/ 5)
      END
      ELSE
      BEGIN
        SELECT @n_label = (Floor(@n_qty / 5)) + 1
      END
    
      WHILE @n_labelcnt < @n_label
      BEGIN
         
        EXECUTE nspg_GetKey 'FWLabelNo', 
        10, 
        @c_barcodeno OUTPUT, 
        @b_success OUTPUT, 
        @n_err  OUTPUT, 
        @c_errmsg OUTPUT
       
        INSERT INTO #TEMP_RESULT
        SELECT @c_orderkey, @n_cartonno, @c_barcodeno

        SELECT @n_labelcnt = @n_labelcnt + 1
        SELECT @n_cartonno = @n_cartonno + 1

      END  -- while labelcnt   
    END -- While orderkey  

    SELECT @n_totalctn = MAX(Cartonno)
    FROM #TEMP_RESULT (NOLOCK)
      
    SELECT ORD.ExternOrderkey as OrderNo, ORD.Company as Company, --ORD.Address1 as Address1, -- (YokeBeen02)
			  ORD.Address2 as Address2, ORD.Address3 as Address3, ORD.Address4 as Address4,
           ORD.City as City, ORD.Route as Route, TR.Cartonno as CartonNo, TR.Barcodeno as BarcodeNo, 
			  @n_totalctn as TotalCarton
    FROM #TEMP_ORD ORD (NOLOCK), 
         #TEMP_RESULT TR (NOLOCK)
    WHERE ORD.Orderkey = TR.Orderkey

    DROP TABLE #TEMP_ORD
    DROP TABLE #TEMP_SKU
    DROP TABLE #TEMP_RESULT
                       
 END -- procedure


GO