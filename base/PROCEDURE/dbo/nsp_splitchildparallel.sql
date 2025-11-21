SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_SplitChildParallel                             */
/* Creation Date: 01-May-2003                                           */
/* Copyright: LF Logistics                                              */
/* Written by:wtshong                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GIT Version: 1.0                                                     */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author       Purposes                                   */
/* 01-May-2003  DLIM     1.0 Initial Creation for Parallel Pick Slip    */
/************************************************************************/

CREATE PROCEDURE [dbo].[nsp_SplitChildParallel] (@c_loadkey NVARCHAR(10),
                                @c_orderkey NVARCHAR(10),
                                @c_pickheaderkey NVARCHAR(10))
AS
BEGIN
/************************************************************************
VERSION		WHEN		WHO		WHAT		
1.0		May2003		DLIM		Initial Creation for Parallel Pick Slip	
*************************************************************************/
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE   @c_pickdetailkey   NVARCHAR(10),
             @c_parentphkey     NVARCHAR(10),
             @n_pdqty           int,
             @c_putawayzone     NVARCHAR(10),
             @c_prevputawayzone NVARCHAR(10),
             @f_stdgrosswgt     float,
             @f_stdcube         float,
             @n_pallet          int,
             @n_maxunit         int,
             @f_maxwgt          float,
             @f_maxcube         float,
             @c_firstpd         NVARCHAR(1),
             @c_splitchild      NVARCHAR(1),
             @n_totalunit       int,
             @f_totalwgt        float,
             @f_totalcube       float, 
             @n_continue        int,
             @c_errmsg          NVARCHAR(255),
             @b_success         int,
             @n_err             int

   DECLARE child_cur CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT pickdetailkey,loc.putawayzone 
   FROM pickdetail(NOLOCK),putawayzone(NOLOCK),loc(NOLOCK)
   WHERE orderkey = @c_orderkey
   AND pickdetail.loc = loc.loc
   AND loc.putawayzone = putawayzone.putawayzone
   ORDER BY putawayzone.putawayzone,pickdetail.loc,pickdetail.sku 
   OPEN child_cur

   SELECT @c_firstpd = 'Y', @c_splitchild = 'N', @c_prevputawayzone = ''
   SELECT @n_totalunit = 0, @f_totalwgt = 0, @f_totalcube = 0
   SELECT @c_parentphkey = @c_pickheaderkey

   FETCH NEXT FROM child_cur INTO @c_pickdetailkey, @c_putawayzone
                          
   WHILE (@@FETCH_STATUS <> - 1)
   BEGIN

      IF @c_putawayzone <> @c_prevputawayzone
         SELECT @c_splitchild = 'Y'
      ELSE
      BEGIN
         SELECT @n_pdqty = pickdetail.qty,
                @f_stdgrosswgt = sku.stdgrosswgt, 
                @f_stdcube = sku.stdcube, 
                @n_pallet = putawayzone.no_pallet, 
                @n_maxunit = palletmaster.maxunit, 
                @f_maxwgt = palletmaster.maxwgt, 
                @f_maxcube = palletmaster.maxcube
         FROM pickdetail(NOLOCK), SKU(NOLOCK), LOC(NOLOCK), PUTAWAYZONE(NOLOCK), PALLETMASTER(NOLOCK)
         WHERE pickdetail.storerkey = sku.storerkey
         AND pickdetail.sku = sku.sku
         AND pickdetail.loc = loc.loc
         AND loc.putawayzone = putawayzone.putawayzone
         AND putawayzone.pallet_type = palletmaster.pallet_type  
         AND pickdetail.pickdetailkey = @c_pickdetailkey

         SELECT @n_totalunit = @n_totalunit + @n_pdqty
         SELECT @f_totalwgt = @f_totalwgt + (@n_pdqty * @f_stdgrosswgt)
         SELECT @f_totalcube = @f_totalcube + (@n_pdqty * @f_stdcube)

         IF @n_totalunit > (@n_pallet * @n_maxunit) OR
            @f_totalwgt > (@n_pallet * @f_maxwgt) OR
            @f_totalcube > (@n_pallet * @f_maxcube)
         BEGIN
            SELECT @c_splitchild = 'Y'
         END
      END
                           
      IF @c_splitchild = 'Y'
      BEGIN
         SELECT @n_totalunit = 0, @f_totalwgt = 0, @f_totalcube = 0
                                 
         IF @c_firstpd = 'Y'
         BEGIN
            SELECT @c_pickheaderkey = REPLACE(@c_pickheaderkey,'P','C')
            SELECT @c_firstpd = 'N'
         END
         ELSE
         BEGIN
            EXECUTE nspg_GetKey
                    'PICKSLIP',
                    9,   
                    @c_pickheaderkey	OUTPUT,
                    @b_success		OUTPUT,
                    @n_err			OUTPUT,
                    @c_errmsg		OUTPUT
                                                         	                                        
     SELECT @c_pickheaderkey = 'C' + @c_pickheaderkey
         END
                                                          
         BEGIN TRAN
         INSERT INTO PICKHEADER
         (PickHeaderKey,OrderKey,ExternOrderKey,PickType,Zone,TrafficCop,ConsigneeKey)
         VALUES
         (@c_pickheaderkey,@c_OrderKey,@c_LoadKey,'0','1','',@c_parentphkey)
                                                                                                 		
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
            IF @@TRANCOUNT >= 1
            BEGIN
               ROLLBACK TRAN
            END
         END
         ELSE
         BEGIN
         IF @@TRANCOUNT > 0 
            COMMIT TRAN
         ELSE
            ROLLBACK TRAN
         END
      END

      BEGIN TRAN
      UPDATE pickdetail
      SET pickslipno = (@c_pickheaderkey)
      FROM pickdetail
      WHERE pickdetailkey = @c_pickdetailkey

      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
         IF @@TRANCOUNT >= 1
         BEGIN
            ROLLBACK TRAN
         END
      END
      ELSE
      BEGIN
      IF @@TRANCOUNT > 0 
         COMMIT TRAN
      ELSE
         ROLLBACK TRAN
      END

      SELECT @c_prevputawayzone = @c_putawayzone
      SELECT @c_splitchild = 'N' 
      FETCH NEXT FROM child_cur INTO @c_pickdetailkey, @c_putawayzone
   END
                        
   CLOSE child_cur
   DEALLOCATE child_cur

END




GO