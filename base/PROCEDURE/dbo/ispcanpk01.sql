SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispCANPK01                                            */
/* Creation Date: 13-JUN-2018                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-5219 - CN PVH Pack reversal cancel packing order           */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 12-Oct-2018  SPChin  1.1   INC0424447 - Bug Fixed                       */
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length        */
/***************************************************************************/  
CREATE PROC [dbo].[ispCANPK01]  
(     @c_PickslipNo  NVARCHAR(10)   
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_Continue       INT,
           @n_StartTranCount INT,
           @c_Pickdetailkey  NVARCHAR(10),
           @c_ExternOrderkey NVARCHAR(50),  --tlting_ext
           @c_Orderkey       NVARCHAR(10),
           @c_Storerkey      NVARCHAR(15),
           @c_Sku            NVARCHAR(20),
           @c_Lot            NVARCHAR(10),
           @c_Loc            NVARCHAR(10),
           --@c_ID             NVARCHAR(10),	--INC0424447
           @c_ID             NVARCHAR(18),	--INC0424447
           @c_ToLoc          NVARCHAR(10),
           @c_ToID           NVARCHAR(18),
           @c_Packkey        NVARCHAR(10),
           @c_UOM            NVARCHAR(10),
           @n_Qty            INT,
           @dt_today         DATETIME
                                     
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT
   
   SET @c_ToLoc = 'PVHTEMP'              
   SET @dt_today = GETDATE()

   IF @@TRANCOUNT = 0
      BEGIN TRAN
   
   IF @n_continue IN (1,2)
   BEGIN   	   	  
      DECLARE cur_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.Orderkey, O.ExternOrderkey, O.Storerkey
         FROM PACKHEADER PH (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
         WHERE PH.Pickslipno = @c_Pickslipno
         UNION ALL
         SELECT O.Orderkey, O.ExternOrderkey, O.Storerkey
         FROM PACKHEADER PH (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON PH.Loadkey = O.Loadkey
         WHERE PH.Pickslipno = @c_Pickslipno
         AND ISNULL(PH.Orderkey,'') = ''

      OPEN cur_ORDER  
             
      FETCH NEXT FROM cur_ORDER INTO @c_Orderkey, @c_ExternOrderkey, @c_Storerkey         
             
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         DECLARE cur_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.Pickdetailkey, PD.Sku, PD.Lot, PD.Loc, PD.Id, PACK.Packkey, PACK.PACKUOM3, PD.Qty
            FROM ORDERS O (NOLOCK) 
            JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
            JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
            JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
            WHERE O.Orderkey = @c_Orderkey

         OPEN cur_PICK  
                
         FETCH NEXT FROM cur_PICK INTO @c_Pickdetailkey, @c_Sku, @c_Lot, @c_Loc, @c_Id, @c_Packkey, @c_UOM, @n_Qty
                
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN
         	 DELETE FROM PICKDETAIL 
         	 WHERE Pickdetailkey = @c_Pickdetailkey
         	 
         	 SELECT @n_err = @@ERROR
         
            IF @n_err <> 0
            BEGIN
	             SELECT @n_continue = 3
			         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60010   
			         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete PICKDETAIL Failed. (ispCANPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
			      END 
			      
			      SET @c_ToID = @c_ExternOrderkey
         
            EXEC dbo.nspItrnAddMove
                          @n_ItrnSysId      = NULL
                       ,  @c_StorerKey      = @c_Storerkey
                       ,  @c_Sku            = @c_Sku
                       ,  @c_Lot            = @c_Lot
                       ,  @c_FromLoc        = @c_Loc
                       ,  @c_FromID         = @c_ID
                       ,  @c_ToLoc          = @c_ToLoc
                       ,  @c_ToID           = @c_ToID
                       ,  @c_Status         = '' 
                       ,  @c_lottable01     = ''
                       ,  @c_lottable02     = ''
                       ,  @c_lottable03     = ''
                       ,  @d_lottable04     = ''
                       ,  @d_lottable05     = ''
                       ,  @c_lottable06     = ''         
                       ,  @c_lottable07     = ''         
                       ,  @c_lottable08     = ''         
                       ,  @c_lottable09     = ''         
                       ,  @c_lottable10     = ''         
                       ,  @c_lottable11     = ''         
                       ,  @c_lottable12     = ''         
                       ,  @d_lottable13     = ''         
                       ,  @d_lottable14     = ''         
                       ,  @d_lottable15     = ''         
                       ,  @n_casecnt        = 0.00
                       ,  @n_innerpack      = 0.00
                       ,  @n_qty            = @n_Qty
                       ,  @n_pallet         = 0.00
                       ,  @f_cube           = 0.00
                       ,  @f_grosswgt       = 0.00
                       ,  @f_netwgt         = 0.00
                       ,  @f_otherunit1     = 0.00
                       ,  @f_otherunit2     = 0.00
                       ,  @c_SourceKey      = @c_PickslipNo
                       ,  @c_SourceType     = 'ispCANPK01'
                       ,  @c_PackKey        = @c_Packkey
                       ,  @c_UOM            = @c_UOM
                       ,  @b_UOMCalc        = 0
                       ,  @d_EffectiveDate  = @dt_today
                       ,  @c_itrnkey        = ''
                       ,  @b_Success        = @b_Success      OUTPUT
                       ,  @n_err            = @n_err          OUTPUT
                       ,  @c_errmsg         = @c_errmsg       OUTPUT
                       ,  @c_MoveRefKey     = ''
                               
            IF @b_success <> 1 
            BEGIN
	             SELECT @n_continue = 3
			      END 
                                  
            FETCH NEXT FROM cur_PICK INTO @c_Pickdetailkey, @c_Sku, @c_Lot, @c_Loc, @c_Id, @c_Packkey, @c_UOM, @n_Qty
         END
         CLOSE cur_PICK
         DEALLOCATE cur_PICK
         
         /*
         IF @n_continue IN(1,2)
         BEGIN         
            UPDATE ORDERS WITH (ROWLOCK)
            SET Status = 'CANC',
                SOStatus = 'CANC'
            WHERE Orderkey = @c_Orderkey

          	SELECT @n_err = @@ERROR	
         
            IF @n_err <> 0
            BEGIN
	             SELECT @n_continue = 3
			         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60020   
			         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update ORDERS Failed. (ispCANPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
			      END 
			      
			      IF EXISTS(SELECT 1 LOADPLANDETAIL(NOLOCK) WHERE Orderkey = @c_Orderkey)
			      BEGIN
			      	 DELETE FROM LOADPLANDETAIL
			      	 WHERE Orderkey = @c_Orderkey

          	   SELECT @n_err = @@ERROR	
               
               IF @n_err <> 0
               BEGIN
	                SELECT @n_continue = 3
			            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60030   
			            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete LOADPLANDETAIL Failed. (ispCANPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
			         END 			      	
			      END

			      IF EXISTS(SELECT 1 WAVEDETAIL(NOLOCK) WHERE Orderkey = @c_Orderkey)
			      BEGIN
			      	 DELETE FROM WAVEDETAIL
			      	 WHERE Orderkey = @c_Orderkey

          	   SELECT @n_err = @@ERROR	
               
               IF @n_err <> 0
               BEGIN
	                SELECT @n_continue = 3
			            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60040   
			            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete WAVEDETAIL Failed. (ispCANPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
			         END 			      	
			      END			                      
         END    
         */
         
         FETCH NEXT FROM cur_ORDER INTO @c_Orderkey, @c_ExternOrderkey, @c_Storerkey         
      END
      CLOSE cur_ORDER
      DEALLOCATE cur_ORDER   
   END
               	   	   	   	   
   QUIT_SP:
   
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispCANPK01'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO