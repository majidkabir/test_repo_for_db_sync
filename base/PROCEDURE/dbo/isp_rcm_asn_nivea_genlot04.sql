SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_ASN_NIVEA_GenLot04                         */
/* Creation Date: 29-May-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-9181 NIVEA Generate Lottable04 from Lottable02          */
/*                                                                      */
/* Called By: ASN Dynamic RCM configure at listname 'RCMConfig'         */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_RCM_ASN_NIVEA_GenLot04]
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

   DECLARE   @n_continue           INT,
             @n_cnt                INT,
             @n_starttcnt          INT
               
   DECLARE   @c_doctype            NCHAR(1)
           , @c_Lottable02         NVARCHAR(18) = ''
           , @c_Lottable09         NVARCHAR(30) = ''
           , @c_SKU                NVARCHAR(20) = ''
           , @c_Storerkey          NVARCHAR(15) = ''
           , @c_ReceiptLineNumber  NVARCHAR(5) = ''
           , @n_TempYear           INT  = 0
           , @n_Year               INT  = 0
           , @n_SUSR1              INT  = 0
           , @dt_Lottable04        DATETIME
           , @n_Week               INT  = 0
           , @n_Day                INT  = 0
           , @b_Debug              INT  = 0
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT RD.ReceiptLineNumber, RD.SKU, RD.Storerkey, SUBSTRING(RD.LOTTABLE02,1,4)
   FROM RECEIPTDETAIL RD (NOLOCK)
   JOIN RECEIPT RH (NOLOCK) ON RH.RECEIPTKEY = RD.RECEIPTKEY AND RH.STORERKEY = RD.STORERKEY
   JOIN SKU S (NOLOCK) ON S.SKU = RD.SKU AND S.StorerKey = RD.StorerKey
   WHERE RD.RECEIPTKEY = @c_Receiptkey 
   AND   RD.BeforeReceivedQty > 0 
   AND   RD.Lottable02 IS NOT NULL
   AND   RD.Lottable02 <> ''

   OPEN CUR_RD  
  
   FETCH NEXT FROM CUR_RD INTO @c_ReceiptLineNumber, @c_SKU, @c_Storerkey, @c_Lottable02  
                           
   WHILE @@FETCH_STATUS <> -1   
   BEGIN
      IF(@n_Continue = 1 OR @n_Continue = 2) --Error Checking
      BEGIN
         IF(ISNUMERIC(@c_Lottable02) = 0)
         BEGIN   
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 82000      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Lottable02: ' + @c_Lottable02 + ' is not a numeric number. (isp_RCM_ASN_NIVEA_GenLot04)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
            GOTO ENDPROC  
         END
         
         IF(CAST(@c_Lottable02 AS INT) <= 0)
         BEGIN   
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 82010     
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Lottable02: ' + @c_Lottable02 + ' <= 0. (isp_RCM_ASN_NIVEA_GenLot04)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
            GOTO ENDPROC  
         END
      END

      --Get Year from GETDATE()
      SELECT @n_TempYear = LEFT(CAST(DATEPART(YEAR,GETDATE()) AS NVARCHAR(4)),3) + LEFT(@c_Lottable02,1)

      --Check Year (For eg. GetDate() = 2020, LEFT(@c_Lottable02,1) = 9, @n_TempYear = 2029, The actual year should be 2029 - 10 = 2019)
      SELECT @n_Year = CASE WHEN @n_TempYear > LEFT(CAST(DATEPART(YEAR,GETDATE()) AS NVARCHAR(4)),4) THEN @n_TempYear - 10 ELSE @n_TempYear END
            ,@n_Week = SUBSTRING(@c_Lottable02,2,2)
            ,@n_Day  = SUBSTRING(@c_Lottable02,4,1)

      --Get SUSR1
      SELECT @n_SUSR1 = CASE WHEN ISNULL(SKU.SUSR1,'') <> '' AND ISNUMERIC(SKU.SUSR1) = 1 AND SKU.SUSR1 > 0 THEN SKU.SUSR1 ELSE 0 END
      FROM  SKU (NOLOCK)
      WHERE SKU.SKU = @c_SKU AND SKU.StorerKey = @c_Storerkey
      
      IF(@n_SUSR1 = 0)
      BEGIN   
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 82020      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': SUSR1 <= 0. (isp_RCM_ASN_NIVEA_GenLot04)'   
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO ENDPROC  
      END

      SELECT @dt_Lottable04 = ((DATEADD (WEEK, @n_Week, DATEADD (YEAR, @n_Year - 1900, 0)) - 4 -
                                DATEPART(dw, DATEADD (WEEK, @n_Week, DATEADD (YEAR, @n_Year - 1900, 0)) - 4) + 1 ) --Find first Day of the given week (Sunday)
                              + @n_Day )                                                                           --Then add the day
                              + @n_SUSR1                                                                           --Then add SUSR1

      SELECT @c_Lottable09  = REPLACE(CONVERT(NVARCHAR(10), ((DATEADD (WEEK, @n_Week, DATEADD (YEAR, @n_Year - 1900, 0)) - 4 -
                              DATEPART(dw, DATEADD (WEEK, @n_Week, DATEADD (YEAR, @n_Year - 1900, 0)) - 4) + 1 )
                              + @n_Day ),111),'/','-') 

      
      IF(@b_Debug = 1)
         SELECT @c_SKU   'SKU'
               ,@c_Lottable02 'Lottable02'
               ,@n_Year  'Year'
               ,@n_Week  'Week'
               ,@n_Day   'Day'
               ,@n_SUSR1 'SUSR1'
               ,@dt_Lottable04 'Lottable04'
               ,@c_Lottable09  'Lottable09'

      BEGIN TRAN
      UPDATE RECEIPTDETAIL
      SET LOTTABLE04 = @dt_Lottable04,
          LOTTABLE09 = @c_Lottable09
      WHERE RECEIPTKEY = @c_Receiptkey AND RECEIPTLINENUMBER = @c_ReceiptLineNumber
      
      SET @n_err = @@ERROR    
     
      IF @n_err <> 0     
      BEGIN    
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 82030    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (isp_RCM_ASN_NIVEA_GenLot04)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO ENDPROC  
      END   
   FETCH NEXT FROM CUR_RD INTO @c_ReceiptLineNumber, @c_SKU, @c_Storerkey, @c_Lottable02  
   END  
   CLOSE CUR_RD  
   DEALLOCATE CUR_RD  
        
ENDPROC: 
 
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_ASN_NIVEA_GenLot04'
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