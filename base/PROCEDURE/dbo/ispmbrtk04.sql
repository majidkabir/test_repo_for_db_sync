SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispMBRTK04                                         */
/* Creation Date:  15-Dec-2014                                          */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  328014-RCM MBOL TNT Shipment File Create                   */
/*                                                                      */
/* Input Parameters:  @c_Mbolkey  - (Mbol #)                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  MBOL RMC Release Pick Task                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/* 23-Dec-2014 NJOW01   1.0  Add Cbolkey parameter so it can call from  */
/*                           MBOL release move task RCM also.           */
/************************************************************************/

CREATE PROC [dbo].[ispMBRTK04]
   @c_MbolKey NVARCHAR(10),
   @b_Success int OUTPUT,
   @n_err     int OUTPUT,
   @c_errmsg  NVARCHAR(250) OUTPUT,
   @n_Cbolkey bigint = 0   
AS
BEGIN
   SET NOCOUNT ON   -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_StartTranCnt int,
           @c_Storerkey NVARCHAR(15),
           @c_SC_MBOL2LOG NVARCHAR(10)

   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1

   SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey, @c_SC_MBOL2LOG = ISNULL(SC.Svalue,'0')
   FROM ORDERS (NOLOCK)
   LEFT JOIN V_Storerconfig2 SC ON ORDERS.Storerkey = SC.Storerkey AND SC.Configkey = 'MBOL2LOG'
   WHERE ORDERS.Mbolkey = @c_Mbolkey

   IF @c_SC_MBOL2LOG  = '1'
   BEGIN
   	  IF NOT EXISTS (SELECT 1 FROM TRANSMITLOG3 (NOLOCK) 
   	                 WHERE Tablename = 'MBOL2LOG' 
   	                 AND Key1 = @c_MBOLKey
   	                 AND Key2 = ''
   	                 AND KEY3 = @c_Storerkey)
   	  BEGIN
         EXEC ispGenTransmitLog3 'MBOL2LOG', @c_MBOLKey, '', @c_StorerKey, '' 
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT              
                                 
         IF @b_success = 1          
         BEGIN              
            EXEC isp_Transmitlog3_ExecuteMaster 'MBOL2LOG' ,@c_Storerkey           
            
            --Remove and need to re-create and send again when MBOL ship
            DELETE FROM Transmitlog3 
            WHERE Tablename = 'MBOL2LOG'  
            AND Key1 = @c_MBOLKey         
            AND Key2 = ''                 
            AND KEY3 = @c_Storerkey                   
         END
      END
                              
   END                             
END

RETURN_SP:

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
 execute nsp_logerror @n_err, @c_errmsg, 'ispMBRTK04'
 --RAISERROR @n_err @c_errmsg
 RETURN
END
ELSE
BEGIN
 SELECT @b_success = 1
 WHILE @@TRANCOUNT > @n_StartTranCnt
 BEGIN
  COMMIT TRAN
 END
 RETURN
END

GO