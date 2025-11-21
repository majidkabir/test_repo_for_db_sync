SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispVSOST01                                         */  
/* Creation Date: 14-May-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#276826 - VFCDC-Order Cancel                             */  
/*                                                                      */ 
/* Input Parameters:  @c_ORderkey  - (ORder #)                          */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */ 
/* Called By: RMC Cancel Order at Order maintenance Screen              */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 13/12/2019   WLChooi  1.1  WMS-11359 - Exclude checking if the wave  */
/*                            is ECOM (WL01)                            */  
/************************************************************************/  

CREATE PROC [dbo].[ispVSOST01] 
   @c_OrderKey    NVARCHAR(10),
   @b_Success     INT OUTPUT, 
   @n_err         INT OUTPUT, 
   @c_errmsg      NVARCHAR(250) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @n_continue        INT
         , @n_StartTCnt       INT
         , @c_Status          NVARCHAR(10)
         , @c_WaveStatus      NVARCHAR(10)
         , @c_WaveType        NVARCHAR(10)  --WL01
         , @c_ListName        NVARCHAR(10)  --WL01


   SET @n_StartTCnt  =  @@TRANCOUNT
   SET @n_continue      = 1
   SET @c_Status        = ''
   SET @c_ListName      = 'ORDERGROUP'      --WL01
   
   --WL01 Start
   -- GET WaveType FROM WAVE  
   SELECT @c_WaveType = W.UserDefine01  
   FROM WAVE W WITH (NOLOCK)  
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.Wavekey = W.Wavekey
   WHERE WD.Orderkey = @c_Orderkey   
  
   IF ISNULL(@c_WaveType,'') = ''  
   BEGIN  
      -- GET FROM ORDERS  
      SELECT TOP 1 @c_WaveType = CODELKUP.Short  
      FROM WAVEDETAIL WD WITH (NOLOCK)   
      JOIN ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)  
      JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Code = O.OrderGroup)  
      WHERE WD.Orderkey = @c_Orderkey   
        AND CODELKUP.Listname = @c_ListName  
   END  
   --WL01 End

   SELECT @c_Status = ISNULL(RTRIM(Status),'')
   FROM ORDERS WITH (NOLOCK)
   WHERE Orderkey = @c_Orderkey

   IF @c_Status IN ( '0', '1', '2' )
   BEGIN
      SET @c_WaveStatus = ''

      SELECT @c_WaveStatus = ISNULL(RTRIM(WAVE.Status),'')
      FROM WAVE WITH (NOLOCK)
      JOIN WAVEDETAIL WITH (NOLOCK) ON (WAVE.Wavekey = WAVEDETAIL.Wavekey)
      WHERE WAVEDETAIL.Orderkey = @c_Orderkey

      IF (@c_Status = '0' AND @c_WaveStatus = '0') AND @c_WaveType <> 'E'   --WL01
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 65001
         SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) 
                       + ': Order#: ' + RTRIM(@c_Orderkey) + ' exists in Wave. Delete order from Wave before cancel. Order Cancel abort.'
         GOTO QUIT_SP
      END

      IF @c_Status IN ('1','2') AND @c_WaveStatus = '0'
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 65002
         SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) 
                       + ': Order#: ' + RTRIM(@c_Orderkey) + ' Allocated in Wave. Unallocate Order & Delete order from Wave before cancel. Order Cancel abort.'
         GOTO QUIT_SP
      END
   END

   QUIT_SP:
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'ispVSOST01'
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- Procedure



GO