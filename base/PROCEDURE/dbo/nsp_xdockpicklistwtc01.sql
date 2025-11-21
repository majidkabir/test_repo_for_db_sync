SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_XDockPickListWTC01                             */
/* Creation Date: 4-JUL-2005                                            */
/* Copyright: IDS                                                       */
/* Written by: Ong                                                      */
/*                                                                      */
/* Purpose:  Create Bacth Pickslip - Reserved for IDSHK WTC (SOS37177)  */
/*           Zone = 'LB'                                                */
/*           Note: Copy from nspXDockPickList and modified              */
/*                                                                      */
/* Input Parameters:  @c_loadkey,  - Loadkey                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_xdock_print_pick_WTC01             */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 05-Sept      Shong         Change the Commit & Rollback control      */
/************************************************************************/

CREATE PROC [dbo].[nsp_XDockPickListWTC01]( @a_s_LoadKey   NVARCHAR(10) )
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF   
      DECLARE
         @c_FirstTime      NVARCHAR(1),
         @c_PrintedFlag    NVARCHAR(1),         
         @n_err            int,
         @n_continue       int,
         @n_cnt            int,
         @c_PickHeaderKey  NVARCHAR(10),
         @b_success        int,
         @c_errmsg         NVARCHAR(255),
         @n_StartTCnt      int,
         @n_intcnt         int

       DECLARE @c_PutZone       NVARCHAR(10),
               @c_OrderKey      NVARCHAR(10), 
               @c_OrderLine     NVARCHAR(5), 
               @c_PickDetailKey NVARCHAR(10)
                     
       SELECT @n_continue=1, @n_intcnt = 0, @n_StartTCnt=@@TRANCOUNT

       SELECT @a_s_LoadKey As Loadkey,
              '          ' As pickheaderkey,
              Orders.OrderKey,
              Orderdetail.OrderLinenumber,
              Pickdetailkey,   
              OrderDetail.Storerkey,
              OrderDetail.SKU,
              SKU.Descr, 
              Pack.CaseCnt,
              Pack.Pallet,
              PickDetail.Qty, 
              PickDetail.Loc,
              loc.putawayzone, 
              Loc.LogicalLocation, 
              UserID= sUser_sName()
       INTO   #XdockPickDetail
       FROM   PickDetail (nolock)
       JOIN OrderDetail (NOLOCK) ON (PickDetail.OrderKey = OrderDetail.OrderKey 
            AND PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber)
       JOIN Orders (NOLOCK) ON (PickDetail.OrderKey = Orders.OrderKey)
       JOIN SKUXLoc SXL (nolock) on (pickdetail.loc = SXL.loc AND SXL.SKU = pickdetail.sku and 
            SXL.Storerkey = pickdetail.storerkey)
       JOIN Loc (nolock) on (SXL.loc = Loc.loc )
       JOIN PACK (NOLOCK) ON (PICKDETAIL.Packkey = PACK.Packkey)
       JOIN SKU (nolock) on (SKU.StorerKey = OrderDetail.StorerKey AND SKU.SKU = PickDetail.SKU)
       WHERE  OrderDetail.LoadKey = @a_s_LoadKey 
       AND PickDetail.qty > 0
       AND PickDetail.Status < '5'
       AND loc.loclevel >= 4


       SELECT @n_cnt = @@ROWCOUNT
       IF @n_cnt = 0 
         SELECT @n_continue = 4
       ELSE
         SELECT @n_intcnt = @n_cnt

       BEGIN TRANSACTION  
                  
       -- Zone = 'LB' for RESERVE where loc.loclevel >= 4
       IF @n_continue = 1 OR @n_continue = 2
       BEGIN  
          SELECT @c_PickHeaderKey = PickHeaderKey 
          FROM PickHeader (NOLOCK) 
          WHERE ExternOrderKey = @a_s_LoadKey
          AND   Zone = 'LB'

          IF dbo.fnc_RTrim(@c_PickHeaderKey) IS NOT NULL AND dbo.fnc_RTrim(@c_PickHeaderKey) <> '' 
          BEGIN
             SELECT @c_FirstTime = 'N'
             SELECT @c_PrintedFlag = 'Y'
          END
          ELSE
          BEGIN
             SELECT @c_FirstTime = 'Y'
             SELECT @c_PrintedFlag = 'N'
          END -- Record Not Exists
       END


       IF @n_continue = 1 OR @n_continue = 2
       BEGIN   
          IF @c_FirstTime = 'Y'
          BEGIN
             EXECUTE nspg_GetKey   'PICKSLIP', 9, @c_PickHeaderKey OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
             IF @b_success = 0
                SELECT @n_continue = 3
             ELSE
             BEGIN
                SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey
                INSERT INTO PICKHEADER (PickHeaderKey,    ExternOrderKey, Zone, TrafficCop)
                                VALUES (@c_PickHeaderKey, @a_s_LoadKey,   'LB', '')
                                
                SELECT @n_err = @@ERROR
                IF @n_err <> 0 
                   SELECT @n_continue = 3
             END
          END
       END
       
       IF @n_continue = 1 OR @n_continue = 2
       BEGIN   
          DECLARE C_XDockPickDetail_LB CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
          SELECT X.OrderKey, X.OrderLinenumber, X.Pickdetailkey  
          FROM #XdockPickDetail X 
          JOIN PICKHEADER P (NOLOCK) ON P.ExternOrderKey = X.LoadKey AND P.Zone = 'LB' 
          ORDER BY Pickdetailkey 
  
          OPEN C_XDockPickDetail_LB 

          FETCH NEXT FROM C_XDockPickDetail_LB INTO @c_OrderKey, @c_OrderLine, @c_PickDetailKey 

          WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2)
          BEGIN
             INSERT INTO RefKeyLookup (OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey, Loadkey)
             VALUES ( @c_OrderKey, @c_OrderLine, @c_PickHeaderKey, @c_PickDetailKey, @a_s_LoadKey)

             IF @@ERROR <> 0 
             BEGIN 
                SELECT @n_continue = 3
             END 

             FETCH NEXT FROM C_XDockPickDetail_LB INTO @c_OrderKey, @c_OrderLine, @c_PickDetailKey  
          END -- while
          CLOSE C_XDockPickDetail_LB
          DEALLOCATE C_XDockPickDetail_LB 
       END

       IF @n_continue=3  -- Error Occured - Process And Return
       BEGIN
          IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_StartTCnt
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

    IF (@n_continue = 1 OR @n_continue = 2)        
    BEGIN 
       SELECT #XdockPickDetail.Loadkey,
              #XdockPickDetail.pickheaderkey,
              #XdockPickDetail.putawayzone, 
              #XdockPickDetail.Loc,
              #XdockPickDetail.SKU,
              #XdockPickDetail.Descr as Descr, 
              #XdockPickDetail.CaseCnt as CaseCnt,
              #XdockPickDetail.Pallet as Pallet,
              sum(#XdockPickDetail.Qty) as QtyAllocated,
              #XdockPickDetail.UserID,
              #XdockPickDetail.LogicalLocation
       FROM #XdockPickDetail 
       GROUP BY #XdockPickDetail.Loadkey,
              #XdockPickDetail.pickheaderkey,
              #XdockPickDetail.putawayzone, 
              #XdockPickDetail.SKU,
              #XdockPickDetail.Loc,
              #XdockPickDetail.Descr, 
              #XdockPickDetail.CaseCnt,
              #XdockPickDetail.Pallet,
              #XdockPickDetail.UserID,
              #XdockPickDetail.LogicalLocation
       ORDER BY #XdockPickDetail.putawayzone, 
              #XdockPickDetail.LogicalLocation,
              #XdockPickDetail.SKU,
              #XdockPickDetail.Loc
   END
   DROP TABLE #XdockPickDetail
   
END /* main procedure */

GO