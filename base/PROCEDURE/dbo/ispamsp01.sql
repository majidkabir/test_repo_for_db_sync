SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispAMSP01                                          */
/* Creation Date: 26-Jan-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 331723-Auto-Move Short Pick                                 */   
/*                                                                      */
/* Called By: isp_AutoMoveShortPick_Wrapper from Pickdetail Trigger     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */ 
/* 09-Apr-2015  CSCHONG  1.0  New lottable 06 to 15 (CS01)              */ 
/* 23-Jul-2019  CHEEMUN  1.1  INC0786810 - Extend ID & SKU length       */ 
/************************************************************************/

CREATE PROC [dbo].[ispAMSP01]   
   @c_Pickdetailkey NVARCHAR(10),  
   @n_ShortQty      INT,
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @c_StorerKey    NVARCHAR(15),  
           @n_Continue     INT,
           @n_StartTCnt    INT,
           @c_Sku          NVARCHAR(20),		--INC0786810
           @c_Lot          NVARCHAR(10),
           @c_Loc          NVARCHAR(10),
           @c_ID           NVARCHAR(18),		--INC0786810
           @c_ShortPickLoc NVARCHAR(10),
           @c_Packkey      NVARCHAR(10),
           @c_UOM          NVARCHAR(10)           
                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
                   
   SELECT @c_Storerkey = PICKDETAIL.Storerkey,
          @c_Sku = PICKDETAIL.Sku,
          @c_Loc = PICKDETAIL.Loc,
          @c_ID = PICKDETAIL.ID,
          @c_Lot = PICKDETAIL.Lot,
          @c_PackKey = SKU.PackKey,
          @c_UOM = PACK.PACKUOM3
   FROM PICKDETAIL (NOLOCK)
   JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku
   JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
   WHERE Pickdetailkey = @c_Pickdetailkey
    
   SELECT TOP 1 @c_ShortPickLoc = UPPER(Code)
   FROM CODELKUP(NOLOCK)
   WHERE Listname = 'SHORTPKLOC'
   AND Storerkey = @c_Storerkey
   
   IF NOT EXISTS(SELECT 1 FROM LOC(NOLOCK) WHERE Loc = @c_ShortPickLoc)
   BEGIN
   	 SELECT @n_Continue = 3 
	    SELECT @n_Err = 38002
	    SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Invalid Short Pick Location ' + RTRIM(ISNULL(@c_ShortPickLoc,'')) +' (ispAMSP01)'
      GOTO QUIT_SP 
   END   
   
   EXECUTE nspItrnAddMove
      @n_ItrnSysId      = NULL,
      @c_itrnkey        = NULL,
      @c_Storerkey      = @c_StorerKey,
      @c_SKU            = @c_SKU,
      @c_Lot            = @c_Lot,
      @c_FromLoc        = @c_Loc,
      @c_FromID         = @c_ID,
      @c_ToLoc          = @c_ShortPickLoc,
      @c_ToID           = @c_ID,
      @c_Status         = '',
      @c_Lottable01     = '',
      @c_Lottable02     = '',
      @c_Lottable03     = '',
      @d_Lottable04     = NULL,
      @d_Lottable05     = NULL,
      @c_Lottable06     = '',              --(CS01)
      @c_Lottable07     = '',              --(CS01)
      @c_Lottable08     = '',              --(CS01) 
      @c_Lottable09     = '',              --(CS01)
      @c_Lottable10     = '',              --(CS01)
      @c_Lottable11     = '',              --(CS01) 
      @c_Lottable12     = '',              --(CS01) 
      @d_Lottable13     = NULL,            --(CS01)
      @d_Lottable14     = NULL,            --(CS01)
      @d_Lottable15     = NULL,            --(CS01)
      @n_casecnt        = 0,
      @n_innerpack      = 0,
      @n_Qty            = @n_ShortQty,
      @n_Pallet         = 0,
      @f_Cube           = 0,
      @f_GrossWgt       = 0,
      @f_NetWgt         = 0,
      @f_OtherUnit1     = 0,
      @f_OtherUnit2     = 0,
      @c_SourceKey      = @c_Pickdetailkey,
      @c_SourceType     = 'ispAMSP01',
      @c_PackKey        = @c_PackKey,
      @c_UOM            = @c_UOM,
      @b_UOMCalc        = 1,
      @d_EffectiveDate  = NULL,
      @b_Success        = @b_Success   OUTPUT,
      @n_err            = @n_Err       OUTPUT,
      @c_errmsg         = @c_Errmsg    OUTPUT
   
      IF @b_Success <> 1
      BEGIN
          SELECT @n_Continue = 3
          GOTO QUIT_SP
      END         
   
   QUIT_SP:
   
	 IF @n_Continue=3  -- Error Occured - Process AND Return
	 BEGIN
	    SELECT @b_Success = 0
	    IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispAMSP01'		
	    --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
	 END
	 ELSE
	 BEGIN
	    SELECT @b_Success = 1
	    WHILE @@TRANCOUNT > @n_StartTCnt
	    BEGIN
	    	COMMIT TRAN
	    END
	    RETURN
	 END  
END  

GO