SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_OTM_TPEX_Interface                             */
/* Creation Date: 23 Apr 2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  336350 & 336353 - Mercury OTM - Update TPEX                */
/*                                                                      */
/* Input Parameters:      @c_TableName                                  */
/*                        @c_Key1                                       */
/*                        @c_Key2                                       */
/*                        @c_Key3                                       */
/*                        @c_TransmitFlag                               */
/*                        @c_TransmitBatch                              */
/*                        @b_Success                                    */
/*                        @n_err                                        */
/*                        @c_errmsg                                     */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Interfaces.                                                  */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  ASN / ORDER RCM Update TPEX                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 11-Feb-2020  CSCHONG 1.0  WMS-12015 revised field logic (CS01)       */
/************************************************************************/

CREATE  PROC   [dbo].[isp_OTM_TPEX_Interface]
               @c_TableName      NVARCHAR(30)
,              @c_Key1           NVARCHAR(10)
,              @c_Key2           NVARCHAR(5)
,              @c_Key3           NVARCHAR(20)
,              @c_TransmitFlag   NVARCHAR(5) = '0'
,              @c_TransmitBatch  NVARCHAR(30) = ''
,              @c_ResendFlag     NCHAR(1) = '0'
,              @b_Success        INT  OUTPUT
,              @n_err            INT  OUTPUT
,              @c_errmsg         NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @n_continue int,
        @n_starttcnt int     

DECLARE @c_trmlogkey NVARCHAR(10)

/*CS01 START*/

DECLARE @c_SORCMNVOTM   NVARCHAR(5)
       ,@c_Facility     NVARCHAR(5)
	   ,@c_storerkey    NVARCHAR(20)
	   ,@c_orderkey     NVARCHAR(20)


	   SET @c_SORCMNVOTM = '0'

/*CS01 END*/

SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''

IF ISNULL(@c_Key1,'') = ''
BEGIN
   RETURN
END


SELECT @c_Key2 = ISNULL(@c_Key2,'')
SELECT @c_Key3 = ISNULL(@c_Key3,'')
SELECT @c_TransmitFlag = ISNULL(@c_TransmitFlag,'0')
SELECT @c_TransmitBatch = ISNULL(@c_TransmitBatch,'')


/*CS01 START*/

SET @c_orderkey = ''
SET @c_storerkey = ''

IF @c_TableName = 'SORCMOTM' 
BEGIN

   SELECT @c_Storerkey = storerkey
   FROM ORDERS OH WITH (NOLOCK)
   where OH.Orderkey = @c_key1

END

SELECT @c_SORCMNVOTM = svalue
FROM STORERCONFIG (NOLOCK)
WHERE Configkey = 'SORCMNVOTM'
AND Storerkey = @c_Storerkey

IF @c_SORCMNVOTM = '1'
BEGIN

 SET @c_TableName = 'SORCMNVOTM'
 SET @c_key3 = @c_Storerkey

END

/*CS01 END*/

IF @n_continue=1 or @n_continue=2
BEGIN
   SELECT @b_success = 1
   IF NOT EXISTS ( SELECT 1 FROM OTMLOG (NOLOCK) WHERE TableName = @c_TableName
                      AND Key1 = @c_Key1 AND Key2 = @c_Key2 AND Key3 = @c_Key3) 
   BEGIN
       INSERT INTO OTMLOG (tablename, key1, key2, key3, transmitflag, TransmitBatch)
       VALUES (@c_TableName, @c_Key1, @c_Key2, @c_Key3, @c_TransmitFlag, @c_TransmitBatch)
       
       SELECT @n_err = @@ERROR
       
       IF @n_err <> 0
       BEGIN
   	      SELECT @n_continue = 3
		      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60001   
		      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert OTMLOG Failed. (isp_OTM_TPEX_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
		   END
   END
   ELSE IF @c_ResendFlag = '1' 
   BEGIN
   	   UPDATE OTMLOG WITH (ROWLOCK)
   	   SET Transmitflag = '0' 
   	   WHERE TableName = @c_TableName
       AND Key1 = @c_Key1 AND Key2 = @c_Key2 AND Key3 = @c_Key3

       SELECT @n_err = @@ERROR
       
       IF @n_err <> 0
       BEGIN
   	      SELECT @n_continue = 3
		      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60002   
		      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update OTMLOG Failed. (isp_OTM_TPEX_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
		   END       
   END

   IF @n_continue = 3  
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
      execute nsp_logerror @n_err, @c_errmsg, "isp_OTM_TPEX_Interface"
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

END -- procedure


GO