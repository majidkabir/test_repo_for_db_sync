SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_WaveCheckAllocateMode_Wrapper                  */  
/* Creation Date: 28-Sep-2017                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-2819 CN PVH Get allocation mode for the wave            */  
/*          Storerconfig WaveCheckAllocateMode_SP={SPName}              */
/*          SPName = ispWVMxx                                           */      
/*                                                                      */  
/* Called By: Wave allocation                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_WaveCheckAllocateMode_Wrapper]  
   @c_WaveKey      NVARCHAR(10),    
   @c_AllocateMode NVARCHAR(10) OUTPUT, --#LC=LoadConso(LoadConsoAllocation must turn on), #WC=Wave conso(WaveConsoAllocation must turn on & loadplan superorderflag must set) , #DC=Discrete
   @b_Success      INT      OUTPUT,
   @n_Err          INT      OUTPUT, 
   @c_ErrMsg       NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,
           @c_SPCode        NVARCHAR(30),
           @c_StorerKey     NVARCHAR(15),
           @c_Facility      NVARCHAR(5),
           @c_SQL           NVARCHAR(MAX),
           @c_option1      NVARCHAR(50),
           @c_option2      NVARCHAR(50),
           @c_option3      NVARCHAR(50),
           @c_option4      NVARCHAR(50),
           @c_option5      NVARCHAR(4000),
           @c_Userdefine01 NVARCHAR(20),
           @c_Userdefine02 NVARCHAR(20)
                       
   SET @n_err        = 0
   SET @b_success    = 1
   SET @c_errmsg     = ''

   SET @n_continue   = 1
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   SET @c_SQL        = ''
   
   SELECT TOP 1 @c_Storerkey = O.Storerkey
               ,@c_facility = O.Facility
               ,@c_Userdefine01 = UPPER(W.Userdefine01)
               ,@c_Userdefine02 = UPPER(W.Userdefine02)
   FROM WAVE W (NOLOCK)
   JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey
   JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey      
   WHERE W.Wavekey = @c_Wavekey
   
   IF @c_Userdefine01 IN('#LC','#WC','#DC')
   BEGIN
   	  SET @c_AllocateMode = @c_Userdefine01
      GOTO QUIT_SP   	  
   END

   IF @c_Userdefine02 IN('#LC','#WC','#DC')
   BEGIN
   	  SET @c_AllocateMode = @c_Userdefine02
      GOTO QUIT_SP   	  
   END
   
   EXECUTE nspGetRight 
      @c_facility,  
      @c_StorerKey,              
      '',  --Sku                    
      'WaveCheckAllocateMode_SP', -- Configkey
      @b_success    OUTPUT,
      @c_SPCode     OUTPUT,
      @n_err        OUTPUT,
      @c_errmsg     OUTPUT,
      @c_option1 OUTPUT,
      @c_option2 OUTPUT,
      @c_option3 OUTPUT,
      @c_option4 OUTPUT,
      @c_option5 OUTPUT

   IF @b_success <> 1
   BEGIN       
       SET @n_continue = 3  
       SET @n_Err = 31214 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = RTRIM(ISNULL(@c_Errmsg,'')) + ' (isp_WaveCheckAllocateMode_Wrapper)'  
       GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_SPCode),'') IN ('','0','1')
   BEGIN       
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_continue = 3  
       SET @n_Err = 31216
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Storerconfig WaveCheckAllocateMode_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                     + '). (isp_WaveCheckAllocateMode_Wrapper)'  
       GOTO QUIT_SP
   END
   
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_WaveKey, @c_AllocateMode OUTPUT, @b_Success OUTPUT, @n_Err OUTPUT,' +
                ' @c_ErrMsg OUTPUT '

   EXEC sp_executesql @c_SQL 
      , N'@c_WaveKey NVARCHAR(10), @c_AllocateMode NVARCHAR(10) OUTPUT, @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT' 
      , @c_WaveKey 
      , @c_AllocateMode OUTPUT
      , @b_Success   OUTPUT                       
      , @n_Err       OUTPUT  
      , @c_ErrMsg    OUTPUT
                        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_continue = 3  
       GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SET @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_WaveCheckAllocateMode_Wrapper'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO