SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_ASN_CopyLottable                           */
/* Creation Date: 09-Aug-2016                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 372562-HK Tory Burch-Finalize copy lottable value for       */ 
/*          duplicate line by RDT UCC Receipt                           */
/*                                                                      */
/* Called By: ASN Dymaic RCM configure at listname 'RCMConfig'          */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_RCM_ASN_CopyLottable]
   @c_Receiptkey NVARCHAR(10),   
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int
           
   DECLARE @c_DuplicateFrom   NVARCHAR(5),
           @c_ReceiptLineNumber NVARCHAR(10)
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
      
   DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DuplicateFrom, ReceiptLineNumber
   FROM RECEIPTDETAIL WITH (NOLOCK)
   WHERE Receiptkey = @c_Receiptkey

   OPEN CUR_RD

   FETCH NEXT FROM CUR_RD INTO @c_DuplicateFrom, @c_ReceiptLineNumber
                         
   WHILE @@FETCH_STATUS <> -1        
   BEGIN   	
   	
   	  IF ISNULL(@c_DuplicateFrom,'') = ''
   	  BEGIN
   	  	 SELECT TOP 1 @c_DuplicateFrom = FIND.ReceiptLineNumber
   	  	 FROM RECEIPTDETAIL RD (NOLOCK)
   	  	 JOIN RECEIPTDETAIL FIND (NOLOCK) ON RD.Receiptkey = FIND.Receiptkey AND RD.Sku = FIND.Sku AND RD.ReceiptLineNumber <> FIND.ReceiptLineNumber
   	  	 WHERE RD.Receiptkey = @c_Receiptkey
   	  	 AND RD.ReceiptLineNumber = @c_ReceiptLineNUmber
   	  	 AND (RD.Userdefine03 = FIND.Userdefine03 OR RD.Userdefine03 = FIND.Userdefine03+FIND.Userdefine02)
   	  	 AND (
   	  	      (ISNULL(RD.Lottable01,'') = '' AND ISNULL(FIND.Lottable01,'') <> '')
   	  	   OR (ISNULL(RD.Lottable02,'') = '' AND ISNULL(FIND.Lottable02,'') <> '')
   	  	   OR (ISNULL(RD.Lottable03,'') = '' AND ISNULL(FIND.Lottable03,'') <> '')
   	  	   OR (ISNULL(RD.Lottable06,'') = '' AND ISNULL(FIND.Lottable06,'') <> '')
   	  	   OR (ISNULL(RD.Lottable07,'') = '' AND ISNULL(FIND.Lottable07,'') <> '')
   	  	   OR (ISNULL(RD.Lottable08,'') = '' AND ISNULL(FIND.Lottable08,'') <> '')
   	  	   OR (ISNULL(RD.Lottable09,'') = '' AND ISNULL(FIND.Lottable09,'') <> '')
   	  	   OR (ISNULL(RD.Lottable10,'') = '' AND ISNULL(FIND.Lottable10,'') <> '')
   	  	   OR (ISNULL(RD.Lottable11,'') = '' AND ISNULL(FIND.Lottable11,'') <> '')
   	  	   OR (ISNULL(RD.Lottable12,'') = '' AND ISNULL(FIND.Lottable12,'') <> '')
   	  	     )
   	  	 ORDER BY FIND.ReceiptLineNumber
   	  END
   	  
      IF ISNULL(@c_DuplicateFrom,'') <> ''
      BEGIN
   	     UPDATE RECEIPTDETAIL WITH (ROWLOCK)  
     	   SET RECEIPTDETAIL.Lottable01 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable01,'') = '' THEN RDF.Lottable01 ELSE RECEIPTDETAIL.Lottable01 END
   	        ,RECEIPTDETAIL.Lottable02 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable02,'') = '' THEN RDF.Lottable02 ELSE RECEIPTDETAIL.Lottable02 END
   	        ,RECEIPTDETAIL.Lottable03 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable03,'') = '' THEN RDF.Lottable03 ELSE RECEIPTDETAIL.Lottable03 END
   	        ,RECEIPTDETAIL.Lottable04 = CASE WHEN CONVERT(VARCHAR(8) ,RECEIPTDETAIL.Lottable04 ,112)='19000101' OR RECEIPTDETAIL.Lottable04 IS NULL THEN RDF.Lottable04 ELSE RECEIPTDETAIL.Lottable04 END
   	        ,RECEIPTDETAIL.Lottable05 = CASE WHEN CONVERT(VARCHAR(8) ,RECEIPTDETAIL.Lottable05 ,112)='19000101' OR RECEIPTDETAIL.Lottable05 IS NULL THEN RDF.Lottable05 ELSE RECEIPTDETAIL.Lottable05 END
   	        ,RECEIPTDETAIL.Lottable06 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable06,'') = '' THEN RDF.Lottable06 ELSE RECEIPTDETAIL.Lottable06 END
   	        ,RECEIPTDETAIL.Lottable07 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable07,'') = '' THEN RDF.Lottable07 ELSE RECEIPTDETAIL.Lottable07 END
   	        ,RECEIPTDETAIL.Lottable08 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable08,'') = '' THEN RDF.Lottable08 ELSE RECEIPTDETAIL.Lottable08 END
   	        ,RECEIPTDETAIL.Lottable09 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable09,'') = '' THEN RDF.Lottable09 ELSE RECEIPTDETAIL.Lottable09 END
   	        ,RECEIPTDETAIL.Lottable10 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable10,'') = '' THEN RDF.Lottable10 ELSE RECEIPTDETAIL.Lottable10 END
   	        ,RECEIPTDETAIL.Lottable11 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable11,'') = '' THEN RDF.Lottable11 ELSE RECEIPTDETAIL.Lottable11 END
   	        ,RECEIPTDETAIL.Lottable12 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable12,'') = '' THEN RDF.Lottable12 ELSE RECEIPTDETAIL.Lottable12 END
   	        ,RECEIPTDETAIL.Lottable13 = CASE WHEN CONVERT(VARCHAR(8) ,RECEIPTDETAIL.Lottable13 ,112)='19000101' OR RECEIPTDETAIL.Lottable13 IS NULL THEN RDF.Lottable13 ELSE RECEIPTDETAIL.Lottable13 END
   	        ,RECEIPTDETAIL.Lottable14 = CASE WHEN CONVERT(VARCHAR(8) ,RECEIPTDETAIL.Lottable14 ,112)='19000101' OR RECEIPTDETAIL.Lottable14 IS NULL THEN RDF.Lottable14 ELSE RECEIPTDETAIL.Lottable14 END
   	        ,RECEIPTDETAIL.Lottable15 = CASE WHEN CONVERT(VARCHAR(8) ,RECEIPTDETAIL.Lottable15 ,112)='19000101' OR RECEIPTDETAIL.Lottable15 IS NULL THEN RDF.Lottable15 ELSE RECEIPTDETAIL.Lottable15 END
   	        , RECEIPTDETAIL.TrafficCop = NULL
   	     FROM RECEIPTDETAIL 
   	     JOIN RECEIPTDETAIL RDF (NOLOCK) ON RECEIPTDETAIL.Receiptkey = RDF.ReceiptKey
   	     WHERE RECEIPTDETAIL.Receiptkey = @c_Receiptkey
   	     AND RECEIPTDETAIL.ReceiptLineNumber = @c_ReceiptLineNumber
   	     AND RDF.ReceiptLineNumber = @c_DuplicateFrom
   	     
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue=3
            SET @n_err = 62030
            SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'Update RECEIPTDETAIL Failed. (ispPRREC04)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO ENDPROC
         END   	  
      END
   	
      FETCH NEXT FROM CUR_RD INTO @c_DuplicateFrom, @c_ReceiptLineNumber
   END
   CLOSE CUR_RD
   DEALLOCATE CUR_RD
              
ENDPROC: 

   IF CURSOR_STATUS( 'LOCAL', 'CUR_RD') in (0 , 1)  
   BEGIN
      CLOSE CUR_RD
      DEALLOCATE CUR_RD
   END 
   
   IF @n_continue=3  -- Error Occured - Process And Return
	 BEGIN
	    SELECT @b_success = 0
	    IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_ASN_CopyLottable'
	    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
	 END
	 ELSE
	    BEGIN
	       SELECT @b_success = 1
	       WHILE @@TRANCOUNT > @n_starttcnt
	       BEGIN
	          COMMIT TRAN
	       END
	       RETURN
	    END	   
END -- End PROC

GO