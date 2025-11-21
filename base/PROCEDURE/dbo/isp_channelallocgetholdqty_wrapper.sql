SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_ChannelAllocGetHoldQty_Wrapper                 */  
/* Creation Date: 30-Nov-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-15746 CN PVH Allocation get channel hold qty            */  
/*          Storerconfig ChannelAllocGetHoldQty_SP={SPName}             */
/*          SPName = ispCHNLHLDxx                                       */      
/*                                                                      */  
/* Called By: Wave allocation                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 27-SEP-2022  NJOW01   1.0  WMS-20812 add parameters                  */
/* 27-SEP-2022  NJOW01   1.0  DEVOPS Combine Script                     */
/************************************************************************/   
CREATE   PROCEDURE [dbo].[isp_ChannelAllocGetHoldQty_Wrapper]    
   @c_StorerKey        NVARCHAR(15), 
   @c_Sku              NVARCHAR(20),  
   @c_Facility         NVARCHAR(5),           
   @c_Lot              NVARCHAR(10),
   @c_Channel          NVARCHAR(20),
   @n_Channel_ID       BIGINT = 0,   
   @n_AllocateQty      INT = 0, --NJOW01        
   @n_QtyLeftToFulFill INT = 0, --NJOW01                                                                   
   @c_SourceKey        NVARCHAR(30) = '',
   @c_SourceType       NVARCHAR(50) = '', 
   @n_ChannelHoldQty   INT      OUTPUT,
   @b_Success          INT      OUTPUT,
   @n_Err              INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,
           @c_SPCode       NVARCHAR(30),
           @c_SQL          NVARCHAR(MAX)
                       
   SET @n_err        = 0
   SET @b_success    = 1
   SET @c_errmsg     = ''
   SET @n_continue   = 1
   SET @c_SPCode     = ''
   SET @c_SQL        = ''
   SET @n_ChannelHoldQty = 0
      
   EXECUTE nspGetRight 
      @c_facility,  
      @c_StorerKey,              
      '',  --Sku                    
      'ChannelAllocGetHoldQty_SP', -- Configkey
      @b_success    OUTPUT,
      @c_SPCode     OUTPUT,
      @n_err        OUTPUT,
      @c_errmsg     OUTPUT

   IF @b_success <> 1
   BEGIN       
       SET @n_continue = 3  
       SET @n_Err = 31214 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = RTRIM(ISNULL(@c_Errmsg,'')) + ' (isp_ChannelAllocGetHoldQty_Wrapper)'  
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
                     + '). (isp_ChannelAllocGetHoldQty_Wrapper)'  
       GOTO QUIT_SP
   END
         
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Storerkey=@c_Storerkey, @c_Sku=@c_Sku, @c_Facility=@c_Facility, @c_Lot=@c_Lot, @c_Channel=@c_Channel, @n_Channel_ID=@n_Channel_ID, @n_AllocateQty=@n_AllocateQty, ' +
                '@n_QtyLeftToFulFill=@n_QtyLeftToFulFill, @c_Sourcekey=@c_Sourcekey, @c_Sourcetype=@c_Sourcetype, @n_ChannelHoldQty=@n_ChannelHoldQty OUTPUT, @b_Success=@b_Success OUTPUT, @n_Err=@n_Err OUTPUT, @c_Errmsg=@c_Errmsg OUTPUT'

   EXEC sp_executesql @c_SQL,
        N'@c_StorerKey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), @c_Lot NVARCHAR(10), @c_Channel NVARCHAR(20), @n_Channel_ID BIGINT, @n_AllocateQty INT, @n_QtyLeftToFulFill INT, @c_Sourcekey NVARCHAR(30),
          @c_SourceType NVARCHAR(50), @n_ChannelHoldQty INT OUTPUT, @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',   
        @c_StorerKey,
        @c_Sku,
        @c_Facility,  
        @c_Lot,
        @c_Channel,
        @n_Channel_ID,
        @n_AllocateQty, --NJOW01
        @n_QtyLeftToFulFill, --NJOW01
        @c_Sourcekey,
        @c_Sourcetype,
        @n_ChannelHoldQty OUTPUT,
        @b_Success        OUTPUT,
        @n_Err            OUTPUT, 
        @c_ErrMsg         OUTPUT
                        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_continue = 3  
       GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SET @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_ChannelAllocGetHoldQty_Wrapper'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO