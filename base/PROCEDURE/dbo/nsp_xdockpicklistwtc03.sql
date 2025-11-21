SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_XDockPickListWTC03                             */
/* Creation Date: 09-Nov-2005                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose:  Create Bacth Pickslip for IDSHK WTC (SOS39325)             */
/*           Note: Copy from nsp_XDockPickListWTC02 and modified        */
/*           Zone = 'LP'                                                */
/*                                                                      */
/* Input Parameters:  @c_loadkey - Loadkey                              */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_xdock_pick_wtc03                   */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nsp_XDockPickListWTC03] (@a_s_LoadKey NVARCHAR(10))
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
      @n_starttcnt     int,
      @n_intcnt        int, 
      @b_debug         NVARCHAR(1), 
      @cSKU            NVARCHAR(20), 
      @c_row           NVARCHAR(10) 

   SELECT 
      @c_firsttime	  = '' ,
      @c_PrintedFlag   = '' ,
      @n_err           = 0 ,
      @n_continue      = 1 ,
      @n_cnt           = 0 ,
      @c_PickHeaderKey = '' ,
      @b_success       = 0 ,
      @c_errmsg        = '' ,
      @n_starttcnt     = @@TRANCOUNT ,
      @n_intcnt        = 0 , 
      @b_debug         = 0 , 
      @cSKU            = '' ,
      @c_row           = '0' 

   SELECT @a_s_LoadKey AS Loadkey,
          OrderDetail.OrderKey,
          ORDERDETAIL.orderlinenumber,
          '                  ' AS pickheaderkey, 
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
     INTO #XdockPickDetail03
     FROM PickDetail (NOLOCK)
     JOIN OrderDetail (NOLOCK) ON (PickDetail.OrderKey = OrderDetail.OrderKey
          AND PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber)
     JOIN SKUXLoc SXL (NOLOCK) ON (pickdetail.loc = SXL.loc AND SXL.SKU = pickdetail.sku 
          AND SXL.Storerkey = pickdetail.storerkey)
     JOIN Loc (NOLOCK) ON (SXL.loc = Loc.loc)
     JOIN PACK (NOLOCK) ON (PICKDETAIL.Packkey = PACK.Packkey)
     JOIN SKU (NOLOCK) ON (SKU.StorerKey = OrderDetail.StorerKey AND SKU.SKU = OrderDetail.SKU)
     JOIN ORDERS (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)
     JOIN CODELKUP (NOLOCK) ON (ORDERS.Type = CODELKUP.Code AND CODELKUP.Listname = 'WTCORDTYPE'
                                AND CODELKUP.Short = 'BATCH')
    WHERE OrderDetail.LoadKey = @a_s_LoadKey 
      AND PickDetail.qty > 0
      AND PickDetail.Status < '5'
      AND loc.loclevel < 4

   SELECT @n_cnt = @@ROWCOUNT
   IF @n_cnt = 0 
	   SELECT @n_continue = 4
   ELSE
      SELECT @n_intcnt = @n_cnt

   -- Zone = 'LP' for GROUND (Pickface), where loc.loclevel < 4
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN  
      IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @a_s_LoadKey AND Zone = 'LP')
      BEGIN
         SELECT @c_firsttime = 'N'
         SELECT @c_PrintedFlag = 'Y'
      END
      ELSE
      BEGIN
         SELECT @c_firsttime = 'Y'
         SELECT @c_PrintedFlag = 'N'
      END -- Record Not Exists

      SET NOCOUNT ON    
      UPDATE PickHeader
         SET TrafficCop = NULL
       WHERE ExternOrderKey = @a_s_LoadKey
         AND Zone = 'LP'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
         SELECT @n_continue = 3
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN  
      IF @b_debug = 1 SELECT 'Started 1st Cursor Sku...'

      DECLARE CurSku CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

      SELECT DISTINCT Sku FROM #XdockPickDetail03 (NOLOCK) 
       ORDER BY Sku 

      OPEN CurSku 
      FETCH NEXT FROM CurSku INTO @cSKU  

      WHILE @@FETCH_STATUS <> -1  -- CurSku Loop 
      BEGIN
         IF @@FETCH_STATUS = 0
         BEGIN
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN 	
               IF @c_firsttime = 'Y'
               BEGIN
                  EXECUTE dbo.nspg_GetKey
                         'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT

                  IF @b_success = 0
                     SELECT @n_continue = 3
                  ELSE
                  BEGIN
                     SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey

                     SELECT @c_row = CONVERT(CHAR(10), CONVERT(INT, @c_row) + 1) 

                     INSERT INTO PICKHEADER(PickHeaderKey, WaveKey, ExternOrderKey, Zone, TrafficCop)   
                     VALUES (@c_pickheaderkey, @c_row, @a_s_LoadKey, 'LP', '')

                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0 
                        SELECT @n_continue = 3
                  END
               END
               ELSE
               BEGIN
                  SELECT @c_pickheaderkey = PickHeaderKey FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @a_s_LoadKey
                     AND Zone = 'LP'
               END
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN   
               IF @c_PrintedFlag = 'N'
               BEGIN
                  UPDATE #XdockPickDetail03 
                     SET pickheaderkey = @c_pickheaderkey 
                   WHERE Sku = @cSKU 

                  UPDATE PickDetail
                     SET PickSlipNo = @c_pickheaderkey,
                         Trafficcop = NULL
                    FROM PickDetail (nolock)
                    JOIN OrderDetail (NOLOCK) ON (PickDetail.OrderKey = OrderDetail.OrderKey AND 
                                                  PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber)
                    JOIN SKUXLoc SXL (NOLOCK) ON (pickdetail.loc = SXL.loc AND SXL.SKU = pickdetail.sku AND 
                                                  SXL.Storerkey = pickdetail.storerkey)
                    JOIN Loc (NOLOCK) ON (SXL.loc = Loc.loc)
                   WHERE OrderDetail.LoadKey = @a_s_LoadKey 
                     AND OrderDetail.Sku = @cSKU 
                     AND PickDetail.qty > 0
                     AND PickDetail.Status < '5'
                     AND loc.loclevel < 4

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0 
                     SELECT @n_continue = 3
               END
               ELSE
               IF @c_PrintedFlag = 'Y'
               BEGIN
                  UPDATE #XdockPickDetail03 
                     SET pickheaderkey = PICKDETAIL.PickslipNo  
                    FROM #XdockPickDetail03 (NOLOCK) 
                    JOIN PICKHEADER (NOLOCK) ON (#XdockPickDetail03.LoadKey = PICKHEADER.ExternOrderKey)
                    JOIN PICKDETAIL (NOLOCK) ON (PICKHEADER.PickHeaderKey = PICKDETAIL.PickslipNo AND 
                                                 #XdockPickDetail03.Sku = PICKDETAIL.Sku)
                   WHERE #XdockPickDetail03.Sku = @cSKU 
               END
            END

            IF (@n_continue = 1 OR @n_continue = 2) AND (@c_firsttime = 'Y')
            BEGIN            
              INSERT INTO RefKeyLookup (OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey, Loadkey)
              SELECT OrderKey, OrderLinenumber, @c_pickheaderkey, Pickdetailkey, LoadKey FROM #XdockPickDetail03 
              WHERE Sku = @cSKU 
              ORDER BY Pickdetailkey 

              SELECT @n_err = @@ERROR
              IF @n_err <> 0 
                 SELECT @n_continue = 3
            END

         END -- IF @@FETCH_STATUS = 0 - 1st CurSku

         FETCH NEXT FROM CurSku INTO @cSKU  
      END -- WHILE @@FETCH_STATUS <> -1 -- CurSku Loop 

      SELECT @c_row = '0'

      CLOSE CurSku 
      DEALLOCATE CurSku

   END -- IF @n_continue = 1 OR @n_continue = 2  


   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
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
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   END

   IF @n_intcnt >= 1 AND (@n_continue = 3 OR @n_continue = 4)
      DELETE FROM #XdockPickDetail03

      SELECT #XdockPickDetail03.Loadkey,
             #XdockPickDetail03.pickheaderkey,
             #XdockPickDetail03.putawayzone, 
             #XdockPickDetail03.Loc,
             #XdockPickDetail03.SKU,
             MIN(#XdockPickDetail03.Descr) AS Descr, 
             MIN(#XdockPickDetail03.CaseCnt) AS CaseCnt,
             MIN(#XdockPickDetail03.Pallet) AS Pallet,
             MIN(#XdockPickDetail03.InnerPack) AS InnerPack,
             SUM(#XdockPickDetail03.Qty) AS QtyAllocated,
             MIN(UserID) AS UserID,
             #XdockPickDetail03.LogicalLocation
      FROM #XdockPickDetail03 
      GROUP BY #XdockPickDetail03.Loadkey,
             #XdockPickDetail03.pickheaderkey,
             #XdockPickDetail03.putawayzone, 
             #XdockPickDetail03.Loc,
             #XdockPickDetail03.SKU,
             #XdockPickDetail03.LogicalLocation 
      ORDER BY #XdockPickDetail03.Loadkey,
             #XdockPickDetail03.pickheaderkey,
             #XdockPickDetail03.SKU,
             #XdockPickDetail03.putawayzone, 
             #XdockPickDetail03.LogicalLocation,
             #XdockPickDetail03.Loc

   SET NOCOUNT OFF
   DROP TABLE #XdockPickDetail03
END /* main procedure */

GO