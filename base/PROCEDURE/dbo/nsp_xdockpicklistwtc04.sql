SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_XDockPickListWTC04                             */
/* Creation Date: 16-Jan-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose:  Create Bacth Pickslip for IDSPH WTC Indent (SOS45186)      */
/*           Note: 1) Copy from nsp_XDockPickListWTC03 and modified     */
/*                 2) Do not limit to Loclevel < 4                      */
/*                                                                      */
/* Input Parameters:  @c_loadkey - Loadkey                              */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_xdock_pick_wtc04                   */
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
/* 20-Jan-2006  MaryVong   SOS45342 Allow to reprint and assign new     */
/*                         pickslipno for re-allocated orderdetail      */
/* 10-Jul-2008  Vanessa    Solved insert null pickslipno at RefKeyLookup*/
/*                         (Vanessa01)                                  */
/* 05-Feb-2009  Rick Liew  Add lottable02 and lottable04 for SOS#127813 */
/************************************************************************/

CREATE PROC [dbo].[nsp_XDockPickListWTC04] (@a_s_LoadKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE
      @c_ReprintFlag   NVARCHAR(1),   -- SOS45342 To indicate reprint
      @n_err           int,
      @n_continue      int,
      @n_cnt           int,
      @c_PickHeaderKey NVARCHAR(10),
      @c_PickSlipNo    NVARCHAR(10),
      @b_success       int,
      @c_errmsg        NVARCHAR(255),
      @n_starttcnt     int,
      @n_intcnt        int, 
      @b_debug         NVARCHAR(1), 
      @c_SKU           NVARCHAR(20), 
      @c_row           NVARCHAR(10) 

   SELECT 
      @c_ReprintFlag   = '' ,
      @n_err           = 0 ,
      @n_continue      = 1 ,
      @n_cnt           = 0 ,
      @c_PickSlipNo    = '' ,
      @b_success       = 0 ,
      @c_errmsg        = '' ,
      @n_starttcnt     = @@TRANCOUNT ,
      @n_intcnt        = 0 , 
      @b_debug         = 0 , 
      @c_SKU           = '' ,
      @c_row           = '0'

   SELECT @a_s_LoadKey AS Loadkey,
          OrderDetail.OrderKey,
          OrderDetail.OrderLineNumber,
          --'                  ' AS PickHeaderKey,
          PickDetail.PickSlipNo,
          PickDetail.PickDetailkey,
          OrderDetail.Storerkey,
          OrderDetail.SKU,
          SKU.Descr, 
          Pack.CaseCnt,
          Pack.Pallet,
          Pack.InnerPack,
	       PickDetail.Qty,
          -- SOS45342
          PrintedFlag =  			 
          CASE WHEN PickDetail.PickSlipNo IS NULL THEN 'N'
			    WHEN PickDetail.PickSlipNo = '' THEN 'N' 
				 ELSE 'Y'
			 END, 
	       PickDetail.Loc,
          Loc.PutawayZone,
          Loc.LogicalLocation,
          UserID= sUser_sName(),
--          CASE WHEN ISDATE(LA.Lottable02) <> 1 THEN '' 
--               ELSE LA.Lottable02
--          END AS Lottable02, -- SOS#127813
          LA.Lottable02, -- SOS#127813
          LA.Lottable04  -- SOS#127813
     INTO #IndentPickDetail
     FROM PickDetail (NOLOCK)
     JOIN OrderDetail (NOLOCK) ON (PickDetail.OrderKey = OrderDetail.OrderKey
          AND PickDetail.OrderLineNumber = OrderDetail.OrderLineNumber)
     JOIN SKUXLoc SXL (NOLOCK) ON (PickDetail.Loc = SXL.Loc AND SXL.SKU = PickDetail.SKU 
          AND SXL.Storerkey = PickDetail.storerkey)
     JOIN Loc (NOLOCK) ON (SXL.Loc = Loc.Loc)
     JOIN PACK (NOLOCK) ON (PickDetail.Packkey = PACK.Packkey)
     JOIN SKU (NOLOCK) ON (SKU.StorerKey = OrderDetail.StorerKey AND SKU.SKU = OrderDetail.SKU)
     JOIN Orders (NOLOCK) ON (OrderDetail.Orderkey = Orders.Orderkey)
     JOIN CODELKUP (NOLOCK) ON (Orders.Type = CODELKUP.Code AND CODELKUP.Listname = 'WTCORDTYPE'
                                AND CODELKUP.Short = 'BATCH')
     JOIN LotAttribute LA (NOLOCK) ON (LA.Storerkey = Pickdetail.StorerKey AND Pickdetail.SKU = SKU.SKU
                                       AND LA.Lot = Pickdetail.Lot)
    WHERE OrderDetail.LoadKey = @a_s_LoadKey 
      AND PickDetail.Qty > 0
      AND PickDetail.Status < '5'

   SELECT @n_cnt = @@ROWCOUNT
   IF @n_cnt = 0 
	   SELECT @n_continue = 4
   ELSE
      SELECT @n_intcnt = @n_cnt

   -- Zone = 'LP' for GROUND (Pickface)
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN  
      IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @a_s_LoadKey AND Zone = 'LP')
      BEGIN
         -- SOS45342
         SELECT @c_ReprintFlag = 'Y'
		   SELECT @c_row = MAX(Convert(int,WaveKey)) FROM PickHeader (NOLOCK) 
		   WHERE ExternOrderKey = @a_s_LoadKey AND Zone = 'LP' 
      END
      ELSE
      BEGIN
         SELECT @c_ReprintFlag = 'N'
         SELECT @c_row = '0'
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

      SELECT DISTINCT Sku FROM #IndentPickDetail (NOLOCK)
      WHERE (PickSlipNo IS NULL OR PickSlipNo = '')   -- SOS45342
        AND PrintedFlag = 'N'                         -- SOS45342
       ORDER BY Sku

      OPEN CurSku 
      FETCH NEXT FROM CurSku INTO @c_SKU  

      WHILE @@FETCH_STATUS <> -1  -- CurSku Loop 
      BEGIN
         IF @@FETCH_STATUS = 0
         BEGIN
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               EXECUTE dbo.nspg_GetKey
                      'PICKSLIP', 9, @c_PickHeaderKey OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT

               IF @b_success = 0
                  SELECT @n_continue = 3
               ELSE
               BEGIN
                  SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey

                  SELECT @c_row = CONVERT(CHAR(10), CONVERT(INT, @c_row) + 1) 

                  INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, ExternOrderKey, Zone, TrafficCop)   
                  VALUES (@c_PickHeaderKey, @c_row, @a_s_LoadKey, 'LP', '')

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0 
                     SELECT @n_continue = 3
               END
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN   
               UPDATE #IndentPickDetail 
                  SET PickSlipNo = @c_PickHeaderKey 
                WHERE Sku = @c_SKU 
			       AND   (PickSlipNo IS NULL OR PickSlipNo = '') 

               UPDATE PickDetail
                  SET PickSlipNo = @c_PickHeaderKey,
                      Trafficcop = NULL
                 FROM PickDetail (nolock)
                 JOIN OrderDetail (NOLOCK) ON (PickDetail.OrderKey = OrderDetail.OrderKey AND 
                                               PickDetail.OrderLineNumber = OrderDetail.OrderLineNumber)
                 JOIN SKUXLoc SXL (NOLOCK) ON (PickDetail.Loc = SXL.Loc AND SXL.SKU = PickDetail.SKU AND 
                                               SXL.Storerkey = PickDetail.Storerkey)
                 JOIN Loc (NOLOCK) ON (SXL.Loc = Loc.Loc)
                WHERE OrderDetail.LoadKey = @a_s_LoadKey 
                  AND OrderDetail.Sku = @c_SKU 
                  AND PickDetail.Qty > 0
                  AND PickDetail.Status < '5'
			         AND (PickSlipNo IS NULL OR PickSlipNo = '')  -- SOS45342

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0 
                     SELECT @n_continue = 3
            END

            IF (@n_continue = 1 OR @n_continue = 2) 
            BEGIN            
              INSERT INTO RefKeyLookup (OrderKey, OrderLineNumber, PickslipNo, PickDetailkey, Loadkey)
              SELECT OrderKey, OrderLineNumber, PickSlipNo, PickDetailkey, LoadKey   --(Vanessa01)
                FROM #IndentPickDetail 
               WHERE Sku = @c_SKU
				     AND PrintedFlag = 'N' -- SOS45342
               ORDER BY PickDetailkey 

              SELECT @n_err = @@ERROR
              IF @n_err <> 0 
                 SELECT @n_continue = 3
            END

         END -- IF @@FETCH_STATUS = 0 - 1st CurSku

         FETCH NEXT FROM CurSku INTO @c_SKU  
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
      DELETE FROM #IndentPickDetail

      SELECT #IndentPickDetail.Loadkey,
             #IndentPickDetail.PickSlipNo,
             #IndentPickDetail.PutawayZone, 
             #IndentPickDetail.Loc,
             #IndentPickDetail.SKU,
             MIN(#IndentPickDetail.Descr) AS Descr, 
             MIN(#IndentPickDetail.CaseCnt) AS CaseCnt,
             MIN(#IndentPickDetail.Pallet) AS Pallet,
             MIN(#IndentPickDetail.InnerPack) AS InnerPack,
             SUM(#IndentPickDetail.Qty) AS QtyAllocated,
             MIN(UserID) AS UserID,
             #IndentPickDetail.LogicalLocation,
             @c_ReprintFlag,   -- SOS45342
             #IndentPickDetail.Lottable02, -- SOS#127813
             #IndentPickDetail.Lottable04  -- SOS#127813
      FROM #IndentPickDetail 
      GROUP BY #IndentPickDetail.Loadkey,
             #IndentPickDetail.PickSlipNo,
             #IndentPickDetail.PutawayZone, 
             #IndentPickDetail.Loc,
             #IndentPickDetail.SKU,
             #IndentPickDetail.LogicalLocation, 
             #IndentPickDetail.Lottable02, -- SOS#127813
             #IndentPickDetail.Lottable04  -- SOS#127813
      ORDER BY #IndentPickDetail.Loadkey,
             #IndentPickDetail.PickSlipNo,
             #IndentPickDetail.SKU,
             #IndentPickDetail.PutawayZone, 
             #IndentPickDetail.LogicalLocation,
             #IndentPickDetail.Loc

   SET NOCOUNT OFF
   DROP TABLE #IndentPickDetail
END /* main procedure */

GO