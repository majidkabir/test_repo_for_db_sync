SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_receivinglabel_tw01                            */
/* Creation Date: 17-Aug-2016                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: [TW] Create Receiving Label for Quiksilver Return Process   */
/*              (SOS374475)                                             */
/*                                                                      */
/* Input Parameters:  @c_DocType - Receipt.Doctype                      */
/*                    @c_Storerkey - Receipt.Storerkey                  */ 
/*                    @d_RecDateStart - Receipt.Receiptdate             */ 
/*                    @d_RecDateSEnd - Receipt.Receiptdate              */ 
/*                    @c_ExtRecKey  - Receipt.ExternReceiptkey          */ 
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_receivinglabel_tw01                */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.9                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   ver. Purposes                                   */
/************************************************************************/

CREATE PROC [dbo].[isp_receivinglabel_tw01] (@c_DocType NVARCHAR(1)
                                    ,@c_Storerkey NVARCHAR(20)
                                    ,@dt_RevDatestart DATETIME 
                                    ,@dt_RevDateEnd  DATETIME
                                    ,@c_ExtRecKey  NVARCHAR(20) = '')
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @n_continue             INT,
            @c_errmsg               NVARCHAR(255),
            @b_success              INT,
            @n_err                  INT,
            @n_starttcnt            INT,
            @c_getExtRecKey         NVARCHAR(20)
           
           
   
   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''

   CREATE TABLE #TEMP_RevLabeltw01
      ( ReceiptKey        NVARCHAR(20) NULL,
        ExternReceiptkey  NVARCHAR(20) NULL,
        Carrierkey        NVARCHAR(15) NULL,
        CarrierName       NVARCHAR(30) NULL,      
        StorerKey         NVARCHAR(15),
        RecDate           DATETIME NULL,
        RetReason         NVARCHAR(150) NULL,
        CQty              INT,           
        QtyExp            INT,
        Reprint           NVARCHAR(1) NULL)  
 
        IF ISNULL(@c_DocType,'') = '' OR @c_Doctype <> 'R'
        BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61900
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) +
                                  'Doctype Parameter cannot be NULL and must be equal to ''R'' (isp_receivinglabel_tw01)' 
        END  
        
        IF ISNULL(@c_storerkey,'') = '' 
        BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61901
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) +
                                  'Storerkey Parameter cannot be NULL  (isp_receivinglabel_tw01)' 
        END  
        
        IF ISNULL(@dt_RevDatestart,'') <> ''
        BEGIN
        	  IF ISNULL(@dt_RevDateEnd,'') = ''
        	  BEGIN
        	  	  
        	 	 SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61902
             SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) +
                                  'ReceiptDateStart Parameter is not NULL so ReceiptDateEnd parameter cannot be NULL  (isp_receivinglabel_tw01)' 
        	  END
        END
        ELSE
        	BEGIN
        	  IF ISNULL(@dt_RevDateEnd,'') <> ''
        	  BEGIN
        	  	  
        	 	 SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61902
             SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) +
                                  'ReceiptDateEnd Parameter is not NULL so ReceiptDateStart parameter cannot be NULL  (isp_receivinglabel_tw01)' 
        	  END
        	END
        
        IF (ISNULL(@dt_RevDatestart,'') = '' AND ISNULL(@dt_RevDateEnd,'') = '' AND ISNULL(@c_ExtRecKey,'') = '') 
        	 BEGIN
        	 	 SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61902
             SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) +
                                  'ReceiptDateStart, ReceiptDateEnd and ExternReceiptkey parameter cannot together be NULL(isp_receivinglabel_tw01)' 
        	 --GOTO
        	 END
 
   BEGIN TRAN

   -- Select all records into temp table
   INSERT INTO #TEMP_RevLabeltw01 (ReceiptKey,ExternReceiptkey,Carrierkey,
                                   CarrierName,StorerKey,RecDate,RetReason,CQty,           
                                   QtyExp,Reprint )    
   SELECT DISTINCT R.ReceiptKey,r.ExternReceiptKey,r.CarrierKey,r.CarrierName,r.StorerKey,r.ReceiptDate,
          cl.[Description], r.ContainerQty,sum(rd.QtyExpected),CASE WHEN ISNULL(r.Signatory,'') ='' THEN 'N' ELSE 'Y' END                                                              
   FROM Receipt R WITH (NOLOCK)
   JOIN RECEIPTDETAIL AS RD WITH (NOLOCK) ON RD.ReceiptKey = R.ReceiptKey
   LEFT OUTER JOIN CODELKUP CL (NOLOCK) ON R.Storerkey = CL.Storerkey AND CL.Listname = 'RETREASON' AND CL.CODE = R.Asnreason                                     
   WHERE (R.Doctype = @c_DocType)
   AND R.StorerKey = @c_Storerkey
   AND R.ReceiptDate >= CASE WHEN ISNULL(@dt_RevDatestart,'') <> '' THEN @dt_RevDatestart ELSE R.ReceiptDate END
   AND R.ReceiptDate <= CASE WHEN ISNULL(@dt_RevDateEnd,'') <> '' THEN @dt_RevDateEnd ELSE R.ReceiptDate END
   AND R.ExternReceiptKey = CASE WHEN ISNULL(@c_ExtRecKey,'') <> '' THEN @c_ExtRecKey ELSE R.ExternReceiptKey END
   GROUP BY R.ReceiptKey,r.ExternReceiptKey,r.CarrierKey,r.CarrierName,r.StorerKey,r.ReceiptDate,
          cl.[Description], r.ContainerQty,CASE WHEN ISNULL(r.Signatory,'') ='' THEN 'N' ELSE 'Y' END  
 
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT ExternReceiptkey  
   FROM   #TEMP_RevLabeltw01    
   WHERE StorerKey = @c_Storerkey
   AND RecDate >= CASE WHEN ISNULL(@dt_RevDatestart,'') <> '' THEN @dt_RevDatestart ELSE RecDate END
   AND RecDate <= CASE WHEN ISNULL(@dt_RevDateEnd,'') <> '' THEN @dt_RevDateEnd ELSE RecDate END
   AND ExternReceiptKey = CASE WHEN ISNULL(@c_ExtRecKey,'') <> '' THEN @c_ExtRecKey ELSE ExternReceiptKey END
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_getExtRecKey    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
   	
   	
      UPDATE RECEIPT
      SET Signatory = 'Y'              
      WHERE Externreceiptkey = @c_getExtRecKey
      AND ISNULL(Signatory,'') = ''
    
   FETCH NEXT FROM CUR_RESULT INTO @c_getExtRecKey
   END
   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT




   GOTO SUCCESS


   FAILURE:
   DELETE FROM #TEMP_RevLabeltw01
   
   SUCCESS:
  
   SELECT *
   FROM #TEMP_RevLabeltw01 
   ORDER BY ExternReceiptkey
                                                        
   DROP TABLE #TEMP_RevLabeltw01

   IF @n_continue = 3  -- Error Occured - Process And Return
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

      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_receivinglabel_tw01'
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
END

GO