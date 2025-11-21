SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_ReTriggerTransmitLog_OWRCPT                    */
/* Creation Date: 05-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose:  Re-Trigger records for interface                           */
/*                                                                      */
/* Input Parameters:      @c_TableName                                  */
/*                        @c_Key1                                       */
/*                        @c_Key2                                       */
/*                        @c_Key3                                       */
/*                        @c_TransmitBatch                              */
/*                        @b_debug                                      */ 
/*                                                                      */
/* Usage:  Re-Trigger records into TransmitLog Table for interface.     */
/*                                                                      */
/* Called By:  Manual upon request                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.   Purposes                               */
/* DD-MMM-YYYY                                                          */
/************************************************************************/

CREATE PROC  [dbo].[isp_ReTriggerTransmitLog_OWRCPT]
             @c_Key1           NVARCHAR(10)
           , @c_Key2           NVARCHAR(5)      = ''
           , @c_Key3           NVARCHAR(20)     = ''
           , @c_TableName      NVARCHAR(30)     = 'OWRCPT'
           , @c_TransmitBatch  NVARCHAR(30)  = ''
           , @b_debug          int          = 0 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int 
   SELECT @n_continue=1 

   IF (ISNULL(@c_Key1,'') = '') OR (ISNULL(@c_TableName,'') = '') 
   BEGIN
      IF @b_debug = 1 
      BEGIN 
         SELECT 'No value being provided on either @c_Key1 = ' + ISNULL(@c_Key1,'') + ', @c_TableName = ' + ISNULL(@c_TableName,'') 
      END 

      RETURN
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      DECLARE @b_Success          int       -- Populated by calls to stored procedures - was the proc successful?
            , @n_err              int       -- Error number returned by stored procedure or this trigger
            , @c_errmsg           NVARCHAR(250) -- Error message returned by stored procedure or this trigger
            , @c_XmitLogKey       NVARCHAR(10)

      SELECT @c_Key3 = ISNULL(RTRIM(@c_Key3), '')
      SELECT @c_TransmitBatch = ISNULL(RTRIM(@c_TransmitBatch), '')

      DECLARE TransmitLogCur CURSOR LOCAL FAST_FORWARD READ_ONLY 
      FOR
         -- Retrieving data from related tables
         SELECT ReceiptLineNumber 
           FROM RECEIPTDETAIL WITH (NOLOCK) 
          WHERE ReceiptKey = @c_Key1 

      IF @b_debug = 1 
      BEGIN 
         SELECT ReceiptLineNumber 
           FROM RECEIPTDETAIL WITH (NOLOCK) 
          WHERE ReceiptKey = @c_Key1 
      END 

      OPEN TransmitLogCur

      IF @b_debug = 1 
      BEGIN 
         SELECT 'Open cursor..'
      END 

      FETCH NEXT FROM TransmitLogCur into @c_Key2  

      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @b_debug = 1 
         BEGIN 
            SELECT 'Begin of cursor..'
         END 

         IF NOT EXISTS ( SELECT 1 FROM TRANSMITLOG WITH (NOLOCK) 
                          WHERE TableName = @c_TableName AND Key1 = @c_Key1 AND Key2 = @c_Key2 AND Key3 = @c_Key3 )
         BEGIN
            BEGIN TRAN 
               SELECT @b_success = 0

               EXECUTE  nspg_getkey 
                       'transmitlogkey',
                        10,
                        @c_XmitLogKey OUTPUT,
                        @b_success OUTPUT,
                        @n_err OUTPUT,
                        @c_errmsg OUTPUT

               INSERT INTO TRANSMITLOG (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag, TransmitBatch)
               VALUES (@c_XmitLogKey, @c_TableName, @c_Key1, @c_Key2, @c_Key3, '0', @c_TransmitBatch)

		      IF NOT @b_success = 1
		      BEGIN
               IF @b_debug = 1 
               BEGIN 
                  SELECT 'Insert into TransmitLog failed. Key1: ', @c_Key1  
               END 
            END
            ELSE 
 	         BEGIN
                COMMIT TRAN
            END
         END

         FETCH NEXT FROM TransmitLogCur into @c_Key2  
      END

      IF @b_debug = 1 
      BEGIN 
         SELECT 'End of cursor..'
      END 

      CLOSE TransmitLogCur
      DEALLOCATE TransmitLogCur
   END -- IF @n_continue=1 OR @n_continue=2
END -- procedure 

GO