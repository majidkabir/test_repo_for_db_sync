SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: mspASNFZ02                                            */
/* Creation Date: 2024-07-15                                               */
/* Copyright: Maersk                                                       */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:   UWP-23788 - Stock Owner Change Without Physical Move         */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: V2                                                             */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/* 2024-09-30  Wan      1.0   Created									                     */
/***************************************************************************/
CREATE   PROC [dbo].[mspASNFZ02]
   @c_Receiptkey        NVARCHAR(10)
,  @b_Success           INT               OUTPUT
,  @n_Err               INT               OUTPUT
,  @c_ErrMsg            NVARCHAR(255)     OUTPUT
,  @c_ReceiptLineNumber NVARCHAR(5) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Debug              INT   = 0
         , @n_Cnt                INT   = 0
         , @n_Continue           INT   = 1
         , @n_StartTranCount     INT   = @@TRANCOUNT

   DECLARE @c_ASNStatus          NVARCHAR(10)   = '0'
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_StorerkeyFromOrder NVARCHAR(15)   = ''
         , @c_ExternOrderKey     NVARCHAR(15)   = ''
         , @c_Sku                NVARCHAR(20)   = ''
         , @c_lot                NVARCHAR(10)   = ''
         , @c_loc                NVARCHAR(10)   = ''
         , @c_Id                 NVARCHAR(18)
		 , @n_Qty                INT   = 0
         , @CUR_RD	             CURSOR

   SET @b_Success= 1
   SET @n_Err    = 0
   SET @c_ErrMsg = ''


    select @c_ExternOrderKey = isnull(R.UserDefine08,'')
		from RECEIPT R with (Nolock) JOIN ORDERS O (nolock)
		on O.ExternOrderKey=R.UserDefine08
		where ReceiptKey=@c_Receiptkey and exists(select 1 from CODELKUP with (Nolock) where LISTNAME='VENDORCODE' and UDF01=R.UserDefine03)
	if(@c_ExternOrderKey='')
	Begin
      GOTO QUIT_SP
	end
	select @c_StorerkeyFromOrder=isnull(StorerKey,'')
		from orders with (Nolock)
		where ExternOrderKey=@c_ExternOrderKey
			and exists(select 1 from CODELKUP with (Nolock) where LISTNAME='VENDORCODE' and UDF01=orders.C_Company)
      If(@c_StorerkeyFromOrder='')
      BEGIN
			  SET @n_Continue = 3
              SET @n_Err = 68010
              SET @c_ErrMsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_Err)
                            + ': Extern order key not found for the . (mspASNFZ02)'
              GOTO QUIT_SP

      END

   SET @CUR_RD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   select pd.Storerkey
         ,pd.Sku
         ,pd.Lot
         ,pd.Loc
         ,pd.ID
         ,Qty = ISNULL(SUM(pd.Qty),0)
		 from ORDERS o (nolock)
   join PICKDETAIL pd (nolock) on o.orderkey=pd.orderkey
   where o.externorderkey=@c_ExternOrderKey and o.StorerKey=@c_StorerkeyFromOrder
    GROUP BY pd.Storerkey
         ,  pd.Sku
         ,  pd.Lot
         ,  pd.Loc
         ,  pd.ID
   ORDER BY MIN(pd.pickdetailkey)

   OPEN @CUR_RD

   FETCH NEXT FROM @CUR_RD INTO @c_Storerkey
                              , @c_Sku
                              , @c_Lot
                              , @c_Loc
                              , @c_ID
                              , @n_Qty

   WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
   BEGIN
      SET @n_Err = 0
      EXEC rdt.rdt_Putaway_PendingMoveIn
         @cUserName        = ''
      ,  @cType            = 'UNLOCK'
      ,  @cFromLoc         = @c_LOC
      ,  @cFromID          = @c_ID
      ,  @cSuggestedLOC    = @c_Loc
      ,  @cStorerKey       = @c_Storerkey
      ,  @nErrNo           = @n_Err       OUTPUT
      ,  @cErrMsg          = @c_Errmsg    OUTPUT
      ,  @cSKU             = @c_SKU
      ,  @nPutawayQTY      = @n_Qty
      ,  @cFromLOT         = @c_Lot
      ,  @cTaskDetailKey   = ''
      ,  @nFunc            = 0
      ,  @nPABookingKey    = 0
      ,  @cMoveQTYAlloc    = '1'
      ,  @cMoveQTYReplen   = '1'

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         GOTO QUIT_SP
      END

      FETCH NEXT FROM @CUR_RD INTO @c_Storerkey
                                 , @c_Sku
                                 , @c_Lot
                                 , @c_Loc
                                 , @c_ID
                                 , @n_Qty
   END
   CLOSE @CUR_RD
   DEALLOCATE @CUR_RD

   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      SET @b_success = 1
   END
   RETURN
END

GO