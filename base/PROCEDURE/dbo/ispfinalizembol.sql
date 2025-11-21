SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispFinalizeMBOL                                             */
/* Creation Date: 08-SEP-2014                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Finalize MBOL                                               */ 
/*                                                                      */
/* Called By: nep_n_cst_MBOL.Event ue_finalizeMBOL                      */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 29-APR-2015 YTWan    1.1   SOS#339247 - LFLHK - Maxim Auto MBOL(WAN01)*/
/* 24-FEB-2017 NJOW01   1.2   WMS-988 add post finalize call custom sp  */ 
/*                            ispMBFZ??                                 */
/* 13-SEP-2018 NJOW02   1.3   WMS-5961 add call From for validatembol   */
/* 01-FEB-2021 NJOW03   1.4   WMS-16002 - LEGO add transmitlog2         */
/* 12-DEC-2021 Wan02    1.5   LFWM-3249 - UAT RG  Dock door booking     */
/*                            backend + SP                              */
/*                            DevOps Combine Order                      */
/************************************************************************/
CREATE PROC [dbo].[ispFinalizeMBOL] 
      @c_MBOLkey        NVARCHAR(10) 
   ,  @b_Success        INT = 0  OUTPUT 
   ,  @n_err            INT = 0  OUTPUT 
   ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
   ,  @b_ReturnCode     INT = 0  OUTPUT      -- (WAN01)
   ,  @b_ContFinalize   INT = 0              -- (WAN01)
AS
BEGIN
   DECLARE @n_StartTranCnt          INT
         , @n_Continue              INT 
                                    
         , @c_Storerkey             NVARCHAR(15)
         , @c_Facility              NVARCHAR(5)
         , @c_OrderKey              NVARCHAR(10)
         , @c_Status                NVARCHAR(10)
         , @c_FinalizeFlag          NVARCHAR(1)                                  
         , @c_FNZMBOLValidation     NVARCHAR(10)   -- (WAN01)
         , @c_FNZMBOLStatus         NVARCHAR(10)   -- (WAN01)
         , @c_PostFinalizeMBOL_SP   NVARCHAR(30)   --NJOW01
         , @c_SQL                   NVARCHAR(2000) --NJOW01

         , @c_MBOLToTransportOrder  NVARCHAR(30) = ''             --(Wan02)
   SET @n_StartTranCnt = @@TRANCOUNT
   SET @n_Continue = 1
   
   SET @c_Storerkey = ''
   SET @c_Facility  = ''
   SET @c_OrderKey  = ''
  
   SET @c_Status       = ''
   SET @c_FinalizeFlag = 'N' 
   SET @b_ReturnCode   = 0

   -- (WAN01) - START
   SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
         , @c_Facility = MBOL.Facility
   FROM MBOL       WITH (NOLOCK)
   JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   JOIN ORDERS     WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
   WHERE MBOL.MBOLKey = @c_MBOLKey
   
   IF @@TRANCOUNT = 0  --NJOW03
      BEGIN TRAN

   IF @b_ContFinalize = 1  
   BEGIN
      GOTO CONTINUE_FNZ
   END 
   -- (WAN01) - END

   SELECT @c_Status = Status 
      , @c_FinalizeFlag = Finalizeflag
   FROM MBOL WITH (NOLOCK) 
   WHERE MBOLkey = @c_MBOLKey

   IF @c_Status = '9'
   BEGIN
      SET @n_continue=3
      SET @n_err=72800
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize rejected. MBOL had been shipped. (ispFinalizeMBOL)'
      GOTO QUIT
   END

   IF @c_FinalizeFlag = 'Y'
   BEGIN
      SET @n_continue=3
      SET @n_err=72805
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize rejected. MBOL had been finalized. (ispFinalizeMBOL)'
      GOTO QUIT
   END

   -- (WAN01) - START
   SET @c_FNZMBOLValidation = '0'
   SET @b_success = 0
   EXECUTE dbo.nspGetRight @c_facility    -- facility   
          ,  @c_Storerkey                 -- Storerkey
          ,  NULL                         -- Sku
          ,  'FNZMBOLValidation'          -- Configkey
          ,  @b_success             OUTPUT
          ,  @c_FNZMBOLValidation   OUTPUT
          ,  @n_err                 OUTPUT
          ,  @c_errmsg              OUTPUT

   IF @b_success = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 72810
      SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Executing nspGetRight (ispFinalizeMBOL)' 
                    + @c_errmsg
      GOTO QUIT
   END
 
   IF @c_FNZMBOLValidation = '1'
   BEGIN
      BEGIN TRANSACTION Validate
      EXEC isp_ValidateMBOL
         @c_MBOLKey   = @c_MBOLKey
      ,  @b_ReturnCode= @b_ReturnCode  OUTPUT  -- 0 = OK, -1 = Error, 1 = Warning        
      ,  @n_err       = @n_err         OUTPUT
      ,  @c_errmsg    = @c_errmsg      OUTPUT
      ,  @c_CallFrom  = 'FinalizeMBOL'  --NJOW02
 
      COMMIT TRANSACTION Validate
      IF @b_ReturnCode <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 72815   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': MBOL Validation Failed. (ispFinalizeMBOL) ' 
                      + @c_errmsg
         GOTO QUIT
      END
   END
 
   CONTINUE_FNZ:

   --(Wan02) - START
   IF @n_Continue IN ( 1, 2 )
   BEGIN
      SELECT @c_MBOLToTransportOrder = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'MBOLToTransportOrder')
      IF @c_MBOLToTransportOrder = '1'
      BEGIN
         EXEC isp_MBOLToTransportOrder
               @c_MBOLkey  = @c_MBOLkey   
            ,  @b_Success  = @b_Success   OUTPUT 
            ,  @n_err      = @n_err       OUTPUT 
            ,  @c_errmsg   = @c_errmsg    OUTPUT
            
         IF @b_Success = 0 
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT
         END  
      END
   END
   --(Wan02) - END
   
   SET @c_FNZMBOLStatus = '0'
   SET @b_success = 0
   EXECUTE dbo.nspGetRight @c_facility    -- facility   
          ,  @c_Storerkey                 -- Storerkey
          ,  NULL                         -- Sku
          ,  'FNZMBOLStatus'              -- Configkey
          ,  @b_success             OUTPUT
          ,  @c_FNZMBOLStatus       OUTPUT
          ,  @n_err                 OUTPUT
          ,  @c_errmsg              OUTPUT

   IF @b_success = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 72820
      SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Executing nspGetRight Fail. (ispFinalizeMBOL)' 
                    + @c_errmsg
      GOTO QUIT
   END
 

   IF NOT EXISTS ( SELECT 1
                   FROM CODELKUP WITH (NOLOCK)
                   WHERE ListName = 'STATUS'
                   AND Code = @c_FNZMBOLStatus 
                   AND @c_FNZMBOLStatus <> '' )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 72825
      SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid FinalizeMBOLStatus Status setup in StorerConfig (ispFinalizeMBOL)' 
      GOTO QUIT
   END
 
   SET @c_FNZMBOLStatus = CASE @c_FNZMBOLStatus WHEN '9' THEN '' 
                                                         WHEN '0' THEN ''
                                                         ELSE @c_FNZMBOLStatus 
                                                         END 
   -- (WAN01) - END
 
   UPDATE MBOL WITH (ROWLOCK)
   SET FinalizeFlag = 'Y'
      ,Status = CASE WHEN @c_FNZMBOLStatus = '' THEN Status ELSE @c_FNZMBOLStatus END  --(Wan01)  
      ,EditWho = SUSER_NAME()
      ,EditDate= GETDATE()
      ,Trafficcop = NULL
   WHERE MBOLKey = @c_MBOLKey

   IF @@ERROR <> 0
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = CONVERT(CHAR(250),@n_err)
      SET @n_err=72830  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE MBOL Failed. (ispFinalizeMBOL)'
      GOTO QUIT
   END  
   
   --NJOW01  
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @b_success = 0      
      SET @c_PostFinalizeMBOL_SP = ''
      
      EXECUTE dbo.nspGetRight @c_facility    -- facility   
             ,  @c_Storerkey                 -- Storerkey
             ,  NULL                         -- Sku
             ,  'PostFinalizeMBOL_SP'     -- Configkey
             ,  @b_success                  OUTPUT
             ,  @c_PostFinalizeMBOL_SP      OUTPUT
             ,  @n_err                      OUTPUT
             ,  @c_errmsg                   OUTPUT

      IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_PostFinalizeMBOL_SP) AND type = 'P')          
      BEGIN          
         SET @c_SQL = 'EXEC ' + @c_PostFinalizeMBOL_SP + ' @c_MBOLkey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '          
         EXEC sp_executesql @c_SQL,          
              N'@c_MBOLKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',                         
              @c_Mbolkey,          
              @b_Success OUTPUT,          
              @n_err OUTPUT,          
              @c_ErrMsg OUTPUT
                  
         IF @b_Success <> 1     
         BEGIN    
            SET @n_Continue = 3
            SET @n_err = 72835   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': MBOL Post Finalize Failed. (ispFinalizeMBOL) ' 
                         + @c_errmsg
            GOTO QUIT
         END         
      END  
   END
   
   IF EXISTS ( SELECT 1 FROM STORERCONFIG WITH (NOLOCK) 
               WHERE storerkey = @c_StorerKey AND ConfigKey = 'MBFNZMBLOG' )
   BEGIN    
      EXEC ispGenTransmitLog3 'MBFNZMBLOG', @c_MBOLKey, '', @c_Storerkey, ''
                           , @b_success   OUTPUT
                           , @n_err       OUTPUT
                           , @c_errmsg    OUTPUT

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(CHAR(250),@n_err)
         SET @n_err=72840   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT TRANMITLOG3 for ''MBFNZMBLOG'' Failed. (ispFinalizeMBOL)'
         GOTO QUIT
      END  
   END

   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ORDERS.Orderkey
         ,ORDERS.Storerkey
   FROM MBOLDETAIL WITH (NOLOCK) 
   JOIN ORDERS     WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
   WHERE MBOLDETAIL.MBOLKey = @c_MBOLKey

   OPEN CUR_ORD
   FETCH NEXT FROM CUR_ORD INTO @c_OrderKey
                              , @c_Storerkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF EXISTS ( SELECT 1 FROM STORERCONFIG WITH (NOLOCK) 
                WHERE storerkey = @c_StorerKey AND ConfigKey = 'MBFNZORLOG' )
      BEGIN    
         EXEC ispGenTransmitLog3 'MBFNZORLOG', @c_OrderKey, '', @c_Storerkey, ''
                              , @b_success   OUTPUT
                              , @n_err       OUTPUT
                              , @c_errmsg    OUTPUT

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(CHAR(250),@n_err)
            SET @n_err=72845  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT TRANMITLOG3 for ''MBFNZORLOG'' Failed. (ispFinalizeMBOL)'
            GOTO QUIT
         END 
      END

      FETCH NEXT FROM CUR_ORD INTO @c_OrderKey
                                 , @c_Storerkey
   END
   CLOSE CUR_ORD
   DEALLOCATE CUR_ORD
   
   --NJOW03
   IF EXISTS ( SELECT 1 FROM STORERCONFIG WITH (NOLOCK) 
               WHERE storerkey = @c_StorerKey AND ConfigKey = 'WSEXCMBFNZ' )
   BEGIN    
      EXEC ispGenTransmitLog2 'WSEXCMBFNZ', @c_MBOLKey, '', @c_Storerkey, ''
                           , @b_success   OUTPUT
                           , @n_err       OUTPUT
                           , @c_errmsg    OUTPUT

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(CHAR(250),@n_err)
         SET @n_err=72840   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT TRANMITLOG2 for ''WSEXCMBFNZ'' Failed. (ispFinalizeMBOL)'
         GOTO QUIT
      END  
   END   

QUIT:
   IF CURSOR_STATUS('LOCAL' , 'CUR_ORD') in (0 , 1)
   BEGIN
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispFinalizeMBOL'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        -- (WAN01)  
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END   
END -- procedure

GO