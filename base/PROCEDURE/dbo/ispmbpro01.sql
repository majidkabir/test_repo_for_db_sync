SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispMBPRO01                                         */
/* Creation Date:  19-Feb-2019                                          */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-7891 CN-MAST MBOL batch process create and finalize    */
/*           mbol status track for interface                            */
/*           storerconfig: MBOLBatchProcess_SP                          */
/*                                                                      */
/* Input Parameters:  @c_Mbollist (mbolkey delimited by comma)          */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RCM MBOL BATCH PROCESS                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/************************************************************************/

CREATE PROC [dbo].[ispMBPRO01]
   @c_Mbollist NVARCHAR(MAX),
   @b_Success int OUTPUT,
   @n_err     int OUTPUT,
   @c_errmsg  NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON   -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_StartTranCnt int
           
   DECLARE @c_Storerkey NVARCHAR(15),
           @c_mbolkey NVARCHAR(10),
           @n_cnt INT
       	 	            
   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @b_Success = 1, @n_err = 0, @c_errmsg = '', @n_cnt = 0
       
   IF @n_continue IN(1,2)
   BEGIN            
      DECLARE CUR_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT MD.Mbolkey, O.Storerkey
         FROM MBOLDETAIL MD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
         WHERE MD.Mbolkey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_Mbollist))
     
      OPEN CUR_MBOL  
      
      FETCH NEXT FROM CUR_MBOL INTO @c_Mbolkey, @c_Storerkey

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN      	 
         SELECT @n_cnt = @n_cnt + 1      	 
         
      	 IF NOT EXISTS(SELECT 1 FROM DOCSTATUSTRACK (NOLOCK)
      	               WHERE TableName = 'MBOL'
      	               AND Documentno = @c_Mbolkey
      	               AND DocStatus = '856(DS)'
      	               AND Storerkey = @c_Storerkey) AND @n_continue IN(1,2)
      	 BEGIN
      	    INSERT INTO DOCSTATUSTRACK (TableName, DocumentNo, Storerkey, DocStatus, TransDate, Finalized)
      	    VALUES ('MBOL', @c_Mbolkey, @c_Storerkey, '856(DS)', GETDATE(), 'Y') 

            SELECT @n_err = @@ERROR  

            IF @n_err <> 0  
            BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert DocStatusTrack Table Failed. (ispMBPRO01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END            
         END      	 

      	 IF NOT EXISTS(SELECT 1 FROM DOCSTATUSTRACK (NOLOCK)
      	               WHERE TableName = 'MBOL'
      	               AND Documentno = @c_Mbolkey
      	               AND DocStatus = 'CSV'
      	               AND Storerkey = @c_Storerkey) AND @n_continue IN(1,2)
      	 BEGIN
      	    INSERT INTO DOCSTATUSTRACK (TableName, DocumentNo, Storerkey, DocStatus, TransDate, Finalized)
      	    VALUES ('MBOL', @c_Mbolkey, @c_Storerkey, 'CSV', GETDATE(), 'Y')

            SELECT @n_err = @@ERROR  

            IF @n_err <> 0  
            BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert DocStatusTrack Table Failed. (ispMBPRO01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END            
      	 END
      	       	 
         FETCH NEXT FROM CUR_MBOL INTO @c_Mbolkey, @c_Storerkey
      END
      CLOSE CUR_MBOL
      DEALLOCATE CUR_MBOL    
   END       	
END

QUIT_SP:

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
 SELECT @b_success = 0
 IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
 BEGIN
  ROLLBACK TRAN
 END
 ELSE
 BEGIN
  WHILE @@TRANCOUNT > @n_StartTranCnt
  BEGIN
   COMMIT TRAN
  END
 END
 execute nsp_logerror @n_err, @c_errmsg, 'ispMBPRO01'
 --RAISERROR @n_err @c_errmsg
 RETURN
END
ELSE
BEGIN
 SELECT @c_errmsg = 'Total ' + CAST(@n_cnt AS NVARCHAR) + ' MBOL proccess completed.'
 SELECT @b_success = 1
 WHILE @@TRANCOUNT > @n_StartTranCnt
 BEGIN
  COMMIT TRAN
 END
 RETURN
END

GO