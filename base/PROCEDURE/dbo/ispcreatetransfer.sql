SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispCreateTransfer                                     */
/* Creation Date: 27-APR-2017                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-1734 - Create tranfer by lot or loc or id                  */
/*                     Design for Re-lot but not for Re-Sku,Storer         */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 08-Oct-2018  NJOW01  1.0   WMS-6456 allow pass in 'EMPTY' at toparameter*/
/*                            indicate blank.                              */
/***************************************************************************/  
CREATE PROC [dbo].[ispCreateTransfer]  
(     @c_FromStorerkey NVARCHAR(15) = ''
  ,   @c_FromSku       NVARCHAR(20) = ''
  ,   @c_FromFacility  NVARCHAR(5) = ''
  ,   @c_FromLot       NVARCHAR(10) = ''  
  ,   @c_FromLoc       NVARCHAR(10) = ''
  ,   @c_FromID        NVARCHAR(18) = ''
  ,   @n_FromQty       INT = 0
  ,   @c_ToLot         NVARCHAR(10) = ''  
  ,   @c_ToLoc         NVARCHAR(10) = ''
  ,   @c_ToID          NVARCHAR(18) = ''
  ,   @n_ToQty         INT = 0
  ,   @c_ToLottable01  NVARCHAR(18) = ''
  ,   @c_ToLottable02  NVARCHAR(18) = ''
  ,   @c_ToLottable03  NVARCHAR(18) = ''
  ,   @dt_ToLottable04  DATETIME = NULL
  ,   @dt_ToLottable05  DATETIME = NULL
  ,   @c_ToLottable06  NVARCHAR(18) = ''
  ,   @c_ToLottable07  NVARCHAR(30) = ''
  ,   @c_ToLottable08  NVARCHAR(30) = ''
  ,   @c_ToLottable09  NVARCHAR(30) = ''
  ,   @c_ToLottable10  NVARCHAR(30) = ''
  ,   @c_ToLottable11  NVARCHAR(30) = ''
  ,   @c_ToLottable12  NVARCHAR(30) = ''
  ,   @dt_ToLottable13  DATETIME = NULL
  ,   @dt_ToLottable14  DATETIME = NULL
  ,   @dt_ToLottable15  DATETIME = NULL
  ,   @c_CopyLottable  NVARCHAR(1) = 'N'
  ,   @c_Finalize      NVARCHAR(1) = 'N'
  ,   @c_Type          NVARCHAR(12) = 'RELOT'
  ,   @c_ReasonCode    NVARCHAR(10)= '01'
  ,   @c_CustomerRefNo NVARCHAR(20) = ''
  ,   @c_Remarks       NVARCHAR(200) = ''
  ,   @c_Transferkey   NVARCHAR(10) = '' OUTPUT
  ,   @b_Success       INT = 0           OUTPUT
  ,   @n_Err           INT = 0       OUTPUT
  ,   @c_ErrMsg        NVARCHAR(255) = '' OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @c_SQL NVARCHAR(MAX),
           @c_ToStorerkey NVARCHAR(15),
           @c_ToSku NVARCHAR(20),
           @c_Packkey NVARCHAR(10),
           @c_UOM NVARCHAR(10),
           @c_Lottable01 NVARCHAR(18),
           @c_Lottable02 NVARCHAR(18),
           @c_Lottable03 NVARCHAR(18),
           @dt_Lottable04 DATETIME,
           @dt_Lottable05 DATETIME,
           @c_Lottable06 NVARCHAR(30),
           @c_Lottable07 NVARCHAR(30),
           @c_Lottable08 NVARCHAR(30),
           @c_Lottable09 NVARCHAR(30),
           @c_Lottable10 NVARCHAR(30),
           @c_Lottable11 NVARCHAR(30),
           @c_Lottable12 NVARCHAR(30),
           @dt_Lottable13 DATETIME,
           @dt_Lottable14 DATETIME,
           @dt_Lottable15 DATETIME,
           @c_ToFacility NVARCHAR(5),
           @c_TransferLineNumber NVARCHAR(5),
           @n_Continue INT,
           @n_StartTranCount INT,
           @n_LineNo INT           

   DECLARE @c_ToLocParm NVARCHAR(10),
           @c_ToIDParm NVARCHAR(18),
           @n_ToQtyParm INT,
           @n_FromQtyParm INT, 
           @c_ToLottable01Parm NVARCHAR(18),
           @c_ToLottable02Parm NVARCHAR(18),
           @c_ToLottable03Parm NVARCHAR(18),
           @dt_ToLottable04Parm DATETIME,
           @dt_ToLottable05Parm DATETIME,
           @c_ToLottable06Parm NVARCHAR(30),
           @c_ToLottable07Parm NVARCHAR(30),
           @c_ToLottable08parm NVARCHAR(30),
           @c_ToLottable09Parm NVARCHAR(30),
           @c_ToLottable10Parm NVARCHAR(30),
           @c_ToLottable11Parm NVARCHAR(30),
           @c_ToLottable12Parm NVARCHAR(30),
           @dt_ToLottable13Parm DATETIME,
           @dt_ToLottable14Parm DATETIME,
           @dt_ToLottable15Parm DATETIME

   SELECT @b_Success=1, @n_Err=0, @c_ErrMsg='', @n_Continue = 1, @n_StartTranCount=@@TRANCOUNT, @n_LineNo=1         
   
   SELECT @n_FromQtyParm = @n_FromQty, 
          @c_ToLocParm = @c_Toloc, 
          @c_ToIDParm = @c_ToID, 
          @n_ToQtyParm = @n_ToQty,
          @c_ToLottable01Parm = @c_ToLottable01,
          @c_ToLottable02Parm = @c_ToLottable02,
          @c_ToLottable03Parm = @c_ToLottable03,
          @dt_ToLottable04Parm = @dt_ToLottable04,
          @dt_ToLottable05Parm = @dt_ToLottable05,
          @c_ToLottable06Parm = @c_ToLottable06,
          @c_ToLottable07Parm = @c_ToLottable07,
          @c_ToLottable08Parm = @c_ToLottable08,
          @c_ToLottable09Parm = @c_ToLottable09,
          @c_ToLottable10Parm = @c_ToLottable10,
          @c_ToLottable11Parm = @c_ToLottable11,
          @c_ToLottable12Parm = @c_ToLottable12,
          @dt_ToLottable13Parm = @dt_ToLottable13,
          @dt_ToLottable14Parm = @dt_ToLottable14,
          @dt_ToLottable15Parm = @dt_ToLottable15
   
   IF ISNULL(@c_Type,'') = ''
      SET @c_Type = 'RELOT'

   IF ISNULL(@c_ReasonCode,'') = ''
      SET @c_ReasonCode = '01'
   
   --Validation
   IF @n_Continue IN(1,2)
   BEGIN
      IF ISNULL(@c_Transferkey,'') <> ''       
      BEGIN
      	 IF NOT EXISTS (SELECT 1 FROM TRANSFER(NOLOCK) 
      	                WHERE Transferkey = @c_Transferkey
      	                AND Status <> '9')
      	 BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63300
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Transferkey (ispCreateTransfer)' + ' ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END
      END

      IF ISNULL(@c_FromLot,'') = '' AND ISNULL(@c_FromLoc,'') = '' AND ISNULL(@c_FromID,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63305
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': From lot,loc,id parameters are blank (ispCreateTransfer)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
      
      IF ISNULL(@n_FromQty,0) <> 0 AND (ISNULL(@c_FromLot,'') = '' OR ISNULL(@c_FromLoc,'') = '') 
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63310
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Empty from lot/loc parameters are not allowed specify from qty (ispCreateTransfer)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END      

      IF ISNULL(@n_ToQty,0) <> 0 AND (ISNULL(@c_FromLot,'') = '' OR ISNULL(@c_FromLoc,'') = '') 
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63320
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Empty from lot/loc parameters are not allowed specify to qty (ispCreateTransfer)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END      
   END
   
   IF @n_Continue IN(1,2)
   BEGIN   	   	
      SELECT @c_SQL = ' DECLARE CUR_INVENTORY CURSOR FAST_FORWARD READ_ONLY FOR  ' +
                      ' SELECT LLI.Storerkey, LLI.Sku, PACK.Packkey, PACK.PACKUOM3, LLI.Lot, LLI.Loc, LLI.ID, (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable, '  +
                      '        LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, LA.Lottable06, LA.Lottable07, LA.Lottable08, ' + 
                      '        LA.Lottable09, LA.Lottable10, LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15, LOC.Facility ' + 
                      ' FROM LOTXLOCXID LLI (NOLOCK) ' +
                      ' JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot ' +
                      ' JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc ' +
                      ' JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku ' +
                      ' JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey ' +
                      ' WHERE (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0 ' +
                      CASE WHEN ISNULL(@c_FromStorerkey,'') <> '' THEN ' AND LLI.Storerkey = ''' + RTRIM(@c_FromStorerkey) + ''' ' ELSE '' END + 
                      CASE WHEN ISNULL(@c_FromSku,'') <> '' THEN ' AND LLI.Sku = ''' + RTRIM(@c_FromSku) + ''' ' ELSE '' END + 
                      CASE WHEN ISNULL(@c_FromFacility,'') <> '' THEN ' AND LOC.Facility = ''' + RTRIM(@c_FromFacility) + ''' ' ELSE '' END + 
                      CASE WHEN ISNULL(@c_FromLot,'') <> '' THEN ' AND LLI.Lot = ''' + RTRIM(@c_FromLot) + ''' ' ELSE '' END + 
                      CASE WHEN ISNULL(@c_FromLoc,'') <> '' THEN ' AND LLI.Loc = ''' + RTRIM(@c_FromLoc) + ''' ' ELSE '' END + 
                      CASE WHEN ISNULL(@c_FromID,'') <> '' THEN ' AND LLI.ID = ''' + RTRIM(@c_FromID) + ''' ' ELSE '' END + 
                      CASE WHEN ISNULL(@c_FromID,'') = '' AND ISNULL(@c_FromLot,'') <> '' AND ISNULL(@c_FromLoc,'') <> '' THEN ' AND LLI.ID = '''' ' ELSE '' END + ' ' +
                      ' ORDER BY LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id '
      EXEC(@c_SQL)                
            
      OPEN CUR_INVENTORY  
      
      FETCH NEXT FROM CUR_INVENTORY INTO @c_FromStorerkey, @c_FromSku, @c_Packkey, @c_UOM, @c_FromLot, @c_FromLoc, @c_FromID, @n_FromQty,
                                         @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, 
                                         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11,
                                         @c_Lottable12, @dt_Lottable13, @dt_Lottable14, @dt_Lottable15, @c_FromFacility
      
      SELECT @c_ToStorerkey = @c_FromStorerkey

      IF ISNULL(@c_ToLocParm,'') <> '' --if specify to loc 
      BEGIN
      	  SELECT @c_ToFacility = Facility
      	  FROM LOC (NOLOCK)
      	  WHERE Loc = @c_ToLocParm      	 	  
      END
      ELSE
         SET @c_ToFacility = @c_FromFacility    
                   
      IF ISNULL(@c_Transferkey,'') <> ''           
      BEGIN
         SELECT @n_LineNo = CAST(MAX(ISNULL(TransferLineNumber,0)) AS INT) + 1
         FROM TRANSFERDETAIL(NOLOCK)
         WHERE Transferkey = @c_Transferkey
      END
      
      IF ISNULL(@c_Transferkey,'') = '' AND @@FETCH_STATUS <> -1 
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspg_getkey
         'TRANSFER'
         , 10
         , @c_TransferKey OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
         
         IF @b_success = 1
         BEGIN
            INSERT INTO TRANSFER (Transferkey, FromStorerkey, ToStorerkey, Type, ReasonCode, CustomerRefNo, Remarks, Facility, ToFacility)
                          VALUES (@c_TransferKey, @c_FromStorerkey, @c_ToStorerkey, @c_Type, @c_ReasonCode, @c_CustomerRefNo, @c_Remarks, @c_FromFacility, @c_ToFacility)
         
   	        SELECT @n_err = @@ERROR
   	        IF  @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63330
   	           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Transfer Failed! (ispCreateTransfer)' + ' ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63340
   	        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Transfer Key Failed! (ispCreateTransfer)' + ' ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END
      END           
                                               
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN        	
      	 SELECT @c_ToLottable01 = '', @c_ToLottable02 = '', @c_ToLottable03 = '', @dt_ToLottable04 = NULL, @dt_ToLottable05 = NULL
      	 SELECT @c_ToLottable06 = '', @c_ToLottable07 = '', @c_ToLottable08 = '', @c_ToLottable09 = '', @c_ToLottable10 = ''
      	 SELECT @c_ToLottable11 = '', @c_ToLottable12 = '', @dt_ToLottable13 = NULL, @dt_ToLottable14 = NULL, @dt_ToLottable15 = NULL
      	 SELECT @c_ToStorerkey = @c_FromStorerkey, @c_ToSku = @c_FromSku      	 
      	 
      	 IF ISNULL(@c_ToLocParm,'') = '' --if not specify to loc 
      	    SET @c_ToLoc = @c_FromLoc
      	 
      	 IF ISNULL(@c_ToIDParm,'') = '' --if not specify to id
            SET @c_ToID = @c_FromID
                        
         IF ISNULL(@n_FromQtyParm,0) <> 0 --if specify from qty 
            SET @n_FromQty = @n_FromQtyParm

         IF ISNULL(@n_ToQtyParm,0) <> 0 --if specify to qty
            SET @n_ToQty = @n_ToQtyParm
         ELSE
            SET @n_ToQty = @n_FromQty  
      	       	
      	 IF ISNULL(@c_ToLot,'') <> ''
      	 BEGIN
      	 	  SELECT @c_ToLottable01 = Lottable01,
      	 	         @c_ToLottable02 = Lottable02,
      	 	         @c_ToLottable03 = Lottable03,
      	 	         @dt_ToLottable04 = Lottable04,
      	 	         @dt_ToLottable05 = Lottable05,
      	 	         @c_ToLottable06 = Lottable06,
      	 	         @c_ToLottable07 = Lottable07,
      	 	         @c_ToLottable08 = Lottable08,
      	 	         @c_ToLottable09 = Lottable09,
      	 	         @c_ToLottable10 = Lottable10,
      	 	         @c_ToLottable11 = Lottable11,
      	 	         @c_ToLottable12 = Lottable12,
      	 	         @dt_ToLottable13 = Lottable13,
      	 	         @dt_ToLottable14 = Lottable14,
      	 	         @dt_ToLottable15 = Lottable15
      	 	  FROM LOTATTRIBUTE (NOLOCK)
      	 	  WHERE LOT = @c_ToLot
      	 END
      	 ELSE
      	 BEGIN
      	 	  IF @c_copylottable = 'Y'
      	 	  BEGIN
      	 	  	 SET @c_ToLottable01 = @c_Lottable01
      	 	  	 SET @c_ToLottable02 = @c_Lottable02
      	 	  	 SET @c_ToLottable03 = @c_Lottable03
      	 	  	 SET @dt_ToLottable04 = @dt_Lottable04
      	 	  	 SET @dt_ToLottable05 = @dt_Lottable05
      	 	  	 SET @c_ToLottable06 = @c_Lottable06
      	 	  	 SET @c_ToLottable07 = @c_Lottable07
      	 	  	 SET @c_ToLottable08 = @c_Lottable08
      	 	  	 SET @c_ToLottable09 = @c_Lottable09
      	 	  	 SET @c_ToLottable10 = @c_Lottable10
      	 	  	 SET @c_ToLottable11 = @c_Lottable11
      	 	  	 SET @c_ToLottable12 = @c_Lottable12
      	 	  	 SET @dt_ToLottable13 = @dt_Lottable13
      	 	  	 SET @dt_ToLottable14 = @dt_Lottable14
      	 	  	 SET @dt_ToLottable15 = @dt_Lottable15
      	 	  END

      	 	  IF @c_ToLottable01Parm  = 'EMPTY'
      	 	     SET @c_ToLottable01 = ''
      	 	  ELSE IF ISNULL(@c_ToLottable01Parm,'') <> '' 
      	 	     SET @c_ToLottable01 = @c_ToLottable01Parm
      	 	     
      	 	  IF @c_ToLottable02Parm  = 'EMPTY'
      	 	     SET @c_ToLottable02 = ''
      	 	  ELSE IF ISNULL(@c_ToLottable02Parm,'') <> '' 
      	 	     SET @c_ToLottable02 = @c_ToLottable02Parm
      	 	     
      	 	  IF @c_ToLottable03Parm  = 'EMPTY'
      	 	     SET @c_ToLottable03 = ''
      	 	  ELSE IF ISNULL(@c_ToLottable03Parm,'') <> '' 
      	 	     SET @c_ToLottable03 = @c_ToLottable03Parm
      	 	     
      	 	  IF @dt_ToLottable04Parm IS NOT NULL 
      	 	     SET @dt_ToLottable04 = @dt_ToLottable04Parm
      	 	  IF @dt_ToLottable05Parm IS NOT NULL 
      	 	     SET @dt_ToLottable05 = @dt_ToLottable05Parm

      	 	  IF @c_ToLottable06Parm  = 'EMPTY'
      	 	     SET @c_ToLottable06 = ''      	 	     
      	 	  ELSE IF ISNULL(@c_ToLottable06Parm,'') <> '' 
      	 	     SET @c_ToLottable06 = @c_ToLottable06Parm
      	 	     
      	 	  IF @c_ToLottable07Parm  = 'EMPTY'
      	 	     SET @c_ToLottable07 = ''
      	 	  ELSE IF ISNULL(@c_ToLottable07Parm,'') <> ''      	 	   
      	 	     SET @c_ToLottable07 = @c_ToLottable07Parm
      	 	     
      	 	  IF @c_ToLottable08Parm  = 'EMPTY'
      	 	     SET @c_ToLottable08 = ''
      	 	  ELSE IF ISNULL(@c_ToLottable08Parm,'') <> '' 
      	 	     SET @c_ToLottable08 = @c_ToLottable08Parm
      	 	     
      	 	  IF @c_ToLottable09Parm  = 'EMPTY'
      	 	     SET @c_ToLottable09 = ''
      	 	  ELSE IF ISNULL(@c_ToLottable09Parm,'') <> '' 
      	 	     SET @c_ToLottable09 = @c_ToLottable09Parm
      	 	     
      	 	  IF @c_ToLottable10Parm  = 'EMPTY'
      	 	     SET @c_ToLottable10 = ''
            ELSE IF ISNULL(@c_ToLottable10Parm,'') <> '' 
      	 	     SET @c_ToLottable10 = @c_ToLottable10Parm
      	 	     
      	 	  IF @c_ToLottable11Parm  = 'EMPTY'
      	 	     SET @c_ToLottable11 = ''
      	 	  ELSE IF ISNULL(@c_ToLottable11Parm,'') <> '' 
      	 	     SET @c_ToLottable11 = @c_ToLottable11Parm

      	 	  IF @c_ToLottable12Parm  = 'EMPTY'
      	 	     SET @c_ToLottable12 = ''      	 	     
      	 	  IF ISNULL(@c_ToLottable12Parm,'') <> '' 
      	 	     SET @c_ToLottable12 = @c_ToLottable12Parm
      	 	     
      	 	  IF @dt_ToLottable13Parm IS NOT NULL 
      	 	     SET @dt_ToLottable13 = @dt_ToLottable13Parm
      	 	  IF @dt_ToLottable14Parm IS NOT NULL 
      	 	     SET @dt_ToLottable14 = @dt_ToLottable14Parm
      	 	  IF @dt_ToLottable15Parm IS NOT NULL 
      	 	     SET @dt_ToLottable15 = @dt_ToLottable15Parm
      	 END
      	             
         SELECT @c_TransferLineNumber = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NChar(5))), 5)
         
         INSERT TRANSFERDETAIL (Transferkey, TransferLineNumber, FromStorerkey, FromSku, FromLot, FromLoc, FromID, FromQty, FromPackkey, FromUOM,
                                Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
                                Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, ToStorerkey, ToSku, ToLot, ToLoc, ToID, ToQty, ToPackkey, ToUOM,
                                ToLottable01, ToLottable02, ToLottable03, ToLottable04, ToLottable05, ToLottable06, ToLottable07, ToLottable08, ToLottable09, ToLottable10,
                                ToLottable11, ToLottable12, ToLottable13, ToLottable14, ToLottable15)
         VALUES (@c_Transferkey, @c_TransferLineNumber, @c_FromStorerkey, @c_FromSku, @c_FromLot, @c_FromLoc, @c_FromID, @n_FromQty, @c_Packkey, @c_UOM,
                 @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                 @c_Lottable11, @c_Lottable12, @dt_Lottable13, @dt_Lottable14, @dt_Lottable15, @c_ToStorerkey, @c_ToSku, @c_ToLot, @c_ToLoc, @c_ToID, @n_ToQty, @c_Packkey, @c_UOM,
                 @c_ToLottable01, @c_ToLottable02, @c_ToLottable03, @dt_ToLottable04, @dt_ToLottable05, @c_ToLottable06, @c_ToLottable07, @c_ToLottable08, @c_ToLottable09, @c_ToLottable10, 
                 @c_ToLottable11, @c_ToLottable12, @dt_ToLottable13, @dt_ToLottable14, @dt_ToLottable15)
         
   	     SELECT @n_err = @@ERROR
   	     IF  @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63350
   	        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert TransferDetail Failed! (ispCreateTransfer)' + ' ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END
     	   
     	   SELECT @n_LineNo = @n_LineNo + 1  
            
                              	
         FETCH NEXT FROM CUR_INVENTORY INTO @c_FromStorerkey, @c_FromSku, @c_Packkey, @c_UOM, @c_FromLot, @c_FromLoc, @c_FromID, @n_FromQty,
                                            @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, 
                                            @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11,
                                            @c_Lottable12, @dt_Lottable13, @dt_Lottable14, @dt_Lottable15, @c_FromFacility
      END            
      CLOSE CUR_INVENTORY
      DEALLOCATE CUR_INVENTORY
   END             
   
   IF ISNULL(@c_Transferkey,'') <> '' AND @c_Finalize = 'Y'
   BEGIN
      EXEC ispFinalizeTransfer @c_Transferkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
      
      IF @b_Success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63360
   	     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Transfer Failed! (ispCreateTransfer)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
   END   
   
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispCreateTransfer'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
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