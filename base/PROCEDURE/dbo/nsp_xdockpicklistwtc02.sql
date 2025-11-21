SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_XDockPickListWTC02                        		*/
/* Creation Date: 4-JUL-2005                           						*/
/* Copyright: IDS                                                       */
/* Written by: Ong                                               			*/
/*                                                                      */
/* Purpose:  Create Bacth Pickslip for IDSHK WTC (SOS37178)             */
/*           Note: Copy from nspXDockPickList and modified              */
/*           Zone = 'LP'                                                */
/*                                                                      */
/* Input Parameters:  @c_loadkey,  - Loadkey										*/
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_xdock_pick_WTC02                   */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                       							*/
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*	05-Sept-2005 Shong         Change the Commit & Rollback control      */
/* 20-Apr-2006  Vicky         SOS#46405 - Generate Pickslipno by Sku    */
/************************************************************************/

CREATE PROC [dbo].[nsp_XDockPickListWTC02]( @a_s_LoadKey NVARCHAR(10), @a_s_sku NVARCHAR(20) )
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF   

      DECLARE
         @c_firsttime	  NVARCHAR(1),
         @c_PrintedFlag   NVARCHAR(1),
         @n_err           int,
         @n_continue      int,
         @n_cnt           int,
         @c_PickHeaderKey NVARCHAR(10),
         @b_success       int,
         @c_errmsg        NVARCHAR(255),
         @n_StartTCnt     int,
         @n_intcnt        int,
         @b_debug         NVARCHAR(1),  -- SOS#46405
         @cSKU            NVARCHAR(20), -- SOS#46405 
         @c_row           NVARCHAR(10)  -- SOS#46405

      DECLARE @c_OrderKey      NVARCHAR(10), 
              @c_OrderLine     NVARCHAR(5), 
              @c_PickDetailKey NVARCHAR(10)

       SELECT @n_continue      = 1, 
              @n_intcnt        = 0, 
              @n_StartTCnt     =@@TRANCOUNT,
              -- SOS#46405 (Start)
			     @c_firsttime	    = '' , 
			     @c_PrintedFlag   = '' , 
			     @n_err           = 0 ,  
			     @n_cnt           = 0 ,  
			     @c_PickHeaderKey = '' , 
			     @b_success       = 0 ,  
			     @c_errmsg        = '' , 
			     @b_debug         = 0 ,  
			     @cSKU            = '' , 
			     @c_row           = '0' 
              -- SOS#46405  (End)

       SELECT @a_s_LoadKey As Loadkey,
              OrderDetail.OrderKey,
              ORDERDETAIL.orderlinenumber,
              '                  ' AS pickheaderkey, -- SOS#46405
              Pickdetailkey,
              OrderDetail.Storerkey,
              OrderDetail.SKU,
              SKU.Descr, 
              Pack.CaseCnt,
              Pack.Pallet,
              Pack.InnerPack,
 	           PickDetail.qty, 
 	           PickDetail.Loc,
              Loc.putawayzone,
              Loc.LogicalLocation,
              UserID= sUser_sName()
       INTO   #XdockPickDetail
       FROM   PickDetail (NOLOCK)
       JOIN OrderDetail (NOLOCK) ON (PickDetail.OrderKey = OrderDetail.OrderKey
            AND PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber)
       JOIN SKUxLOC SXL (NOLOCK) ON (pickdetail.loc = SXL.loc AND SXL.SKU = pickdetail.sku and 
            SXL.Storerkey = pickdetail.storerkey)
       JOIN Loc (NOLOCK) ON (SXL.loc = Loc.loc)
       JOIN PACK (NOLOCK) ON (PICKDETAIL.Packkey = PACK.Packkey)
       JOIN SKU (NOLOCK) ON (SKU.StorerKey = OrderDetail.StorerKey AND SKU.SKU = OrderDetail.SKU)
       WHERE  OrderDetail.LoadKey = @a_s_LoadKey 
       AND PickDetail.qty > 0
       AND PickDetail.Status < '5'
       AND loc.loclevel < 4

       SELECT @n_cnt = @@ROWCOUNT 

       IF @n_cnt = 0 
 	      SELECT @n_continue = 4
       ELSE
         SELECT @n_intcnt = @n_cnt

       BEGIN TRANSACTION  

       -- Zone = 'LP' for GROUND (Pickface), where loc.loclevel < 4
       IF (@n_continue = 1 OR @n_continue = 2)
       BEGIN  
          SELECT @c_pickheaderkey = PickHeaderKey 
          FROM PickHeader (NOLOCK) 
          WHERE ExternOrderKey = @a_s_LoadKey
          AND   Zone = 'LP'

          IF dbo.fnc_RTrim(@c_pickheaderkey) IS NOT NULL AND dbo.fnc_RTrim(@c_pickheaderkey) <> '' 
          BEGIN
             SELECT @c_firsttime = 'N'
             SELECT @c_PrintedFlag = 'Y'
          END
          ELSE
          BEGIN
             SELECT @c_firsttime = 'Y'
             SELECT @c_PrintedFlag = 'N'
          END -- Record Not Exists
       END 

   -- SOS#46405  (Start)
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN  
      IF @b_debug = 1 SELECT 'Started 1st Cursor Sku...'

      DECLARE CurSku CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

      SELECT DISTINCT Sku FROM #XdockPickDetail (NOLOCK) 
      ORDER BY Sku 

      OPEN CurSku 
      FETCH NEXT FROM CurSku INTO @cSKU  

      WHILE @@FETCH_STATUS <> -1  -- CurSku Loop 
      BEGIN
         IF @@FETCH_STATUS = 0
         BEGIN
			    IF (@n_continue = 1 OR @n_continue = 2)
			    BEGIN 	
			       IF @c_firsttime = 'Y'
			       BEGIN
			 	       EXECUTE nspg_GetKey   'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
			          IF @b_success = 0
			             SELECT @n_continue = 3
			          ELSE
			          BEGIN
			             SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey

                      SELECT @c_row = CONVERT(CHAR(10), CONVERT(INT, @c_row) + 1) 
			
			             INSERT INTO PICKHEADER(PickHeaderKey,  WaveKey, ExternOrderKey, Zone, TrafficCop)   
			                            VALUES (@c_pickheaderkey, @c_row, @a_s_LoadKey, 'LP', '')
			
			             SELECT @n_err = @@ERROR
			             IF @n_err <> 0 
			             BEGIN 
			                SELECT @n_continue = 3
			             END
                      
                      IF (@n_continue = 1 OR @n_continue = 2)
                      BEGIN
-- 		                SET @n_cnt = 0 
-- 		
-- 		                DECLARE C_XDockPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
-- 		                SELECT X.OrderKey, X.OrderLinenumber, X.Pickdetailkey  
-- 		                FROM #XdockPickDetail X 
-- 		                JOIN PICKHEADER P (NOLOCK) ON P.ExternOrderKey = X.LoadKey AND P.Zone = 'LP' 
-- 		                ORDER BY Pickdetailkey 
-- 		        
-- 		                OPEN C_XDockPickDetail 
-- 		
-- 		                FETCH NEXT FROM C_XDockPickDetail INTO @c_OrderKey, @c_OrderLine, @c_PickDetailKey 
-- 		
-- 		                WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2)
-- 		                BEGIN
-- 		                   INSERT INTO RefKeyLookup (OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey, Loadkey)
-- 		                   VALUES ( @c_OrderKey, @c_OrderLine, @c_pickheaderkey, @c_PickDetailKey, @a_s_LoadKey)
-- 		
-- 		                   IF @@ERROR <> 0 
-- 		                   BEGIN 
-- 		                      SELECT @n_continue = 3
-- 		                   END 
-- 		
-- 		                   FETCH NEXT FROM C_XDockPickDetail INTO @c_OrderKey, @c_OrderLine, @c_PickDetailKey  
-- 		                END -- while
-- 		                CLOSE C_XDockPickDetail
-- 		                DEALLOCATE C_XDockPickDetail 

                      UPDATE #XdockPickDetail 
                         SET pickheaderkey = @c_pickheaderkey 
                      WHERE Sku = @cSKU 

                      INSERT INTO RefKeyLookup (OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey, Loadkey)
                      SELECT OrderKey, OrderLinenumber, @c_pickheaderkey, Pickdetailkey, LoadKey FROM #XdockPickDetail 
                      WHERE Sku = @cSKU 
                      ORDER BY Pickdetailkey 

                      SELECT @n_err = @@ERROR
                      IF @n_err <> 0 
                        SELECT @n_continue = 3
                      END
		              END -- RefKeyLookup
		          END  -- Pickheaderkey
		       END  -- Firsttime = Y
            END -- IF @@FETCH_STATUS = 0 - 1st CurSku
           FETCH NEXT FROM CurSku INTO @cSKU  
      END -- WHILE @@FETCH_STATUS <> -1 -- CurSku Loop 

      SELECT @c_row = '0'

      CLOSE CurSku 
      DEALLOCATE CurSku

   END -- IF @n_continue = 1 OR @n_continue = 2  

  IF (@n_continue = 1 OR @n_continue = 2)
  BEGIN
   IF @c_PrintedFlag = 'Y'
    BEGIN
      UPDATE #XdockPickDetail 
         SET pickheaderkey = RefKeyLookup.PickslipNo  
        FROM #XdockPickDetail (NOLOCK) 
        JOIN RefKeyLookup (NOLOCK) ON (#XdockPickDetail.LoadKey = RefKeyLookup.Loadkey
                                       AND #XdockPickDetail.Orderkey = RefKeyLookup.Orderkey
                                       AND #XdockPickDetail.Orderlinenumber = RefKeyLookup.OrderLinenumber)
    END -- Printedflag = Y
   END --  IF (@n_continue = 1 OR @n_continue = 2)
   -- SOS#46405  (End)

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
       IF @@TRANCOUNT = 1 OR @@TRANCOUNT > @n_StartTCnt
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
    END
    ELSE
    BEGIN
       WHILE @@TRANCOUNT > @n_StartTCnt
       BEGIN
          COMMIT TRAN
       END
    END

    IF @n_intcnt  >= 1 AND (@n_continue = 3 OR @n_continue = 4)
      DELETE FROM #XdockPickDetail

    IF (@n_continue = 1 OR @n_continue = 2)        
    BEGIN 
       SELECT #XdockPickDetail.Loadkey,
              --@c_pickheaderkey As pickheaderkey,
              #XdockPickDetail.pickheaderkey, -- SOS#46405
              #XdockPickDetail.putawayzone, 
              #XdockPickDetail.Loc,
              #XdockPickDetail.SKU,
              min(#XdockPickDetail.Descr) as Descr, 
              min(#XdockPickDetail.CaseCnt) as CaseCnt,
              min(#XdockPickDetail.Pallet) as Pallet,
              min(#XdockPickDetail.InnerPack) as InnerPack,
              sum(#XdockPickDetail.Qty) as QtyAllocated,
              min(UserID) as UserID,
              #XdockPickDetail.LogicalLocation
       FROM #XdockPickDetail 
		 WHERE #XdockPickDetail.SKU = @a_s_sku 
       GROUP BY #XdockPickDetail.Loadkey,
              #XdockPickDetail.pickheaderkey,
              #XdockPickDetail.putawayzone, 
              #XdockPickDetail.Loc,
              #XdockPickDetail.SKU,
              #XdockPickDetail.LogicalLocation 
       ORDER BY #XdockPickDetail.Loadkey,
              #XdockPickDetail.pickheaderkey,
              #XdockPickDetail.putawayzone, 
              #XdockPickDetail.LogicalLocation,
              #XdockPickDetail.SKU,
              #XdockPickDetail.Loc

       DROP TABLE #XdockPickDetail 
   END 
END /* main procedure */

GO