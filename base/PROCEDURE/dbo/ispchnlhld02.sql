SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispCHNLHLD02                                       */
/* Creation Date: 24-MAY-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-17101 MY Adidas Allocation get channel hold qty         */   
/*                                                                      */
/* Called By: isp_ChannelAllocGetHoldQty_Wrapper from allocation        */
/*            Storerconfig: ChannelAllocGetHoldQty_SP                   */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
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

CREATE PROC [dbo].[ispCHNLHLD02]   
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
     
   DECLARE @n_Continue     INT,
           @n_StartTCnt    INT
                                             
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	
   DECLARE @c_C_AttributeLbl01     NVARCHAR(30)=''
          ,@c_C_AttributeLbl02     NVARCHAR(30)=''
          ,@c_C_AttributeLbl03     NVARCHAR(30)=''
          ,@c_C_AttributeLbl04     NVARCHAR(30)=''
          ,@c_C_AttributeLbl05     NVARCHAR(30)=''         
          ,@c_C_Attribute01        NVARCHAR(30)=''
          ,@c_C_Attribute02        NVARCHAR(30)=''
          ,@c_C_Attribute03        NVARCHAR(30)=''
          ,@c_C_Attribute04        NVARCHAR(30)=''
          ,@c_C_Attribute05        NVARCHAR(30)=''
          ,@c_SQL                  NVARCHAR(MAX)
          ,@n_Qty                  INT
          ,@c_Condition            NVARCHAR(2000)

   SET @n_ChannelHoldQty = 0   
      
   SELECT @c_C_AttributeLbl01 = cac.C_AttributeLabel01
         ,@c_C_AttributeLbl02 = cac.C_AttributeLabel02
         ,@c_C_AttributeLbl03 = cac.C_AttributeLabel03
         ,@c_C_AttributeLbl04 = cac.C_AttributeLabel04
         ,@c_C_AttributeLbl05 = cac.C_AttributeLabel05
   FROM   ChannelAttributeConfig AS cac WITH(NOLOCK)
   WHERE  cac.StorerKey = @c_StorerKey

   IF @@ROWCOUNT = 0
   BEGIN
         SELECT @n_Continue = 3 
         SELECT @n_Err = 36010
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +
                            ': StorerKey= ' + ISNULL(RTRIM(@c_StorerKey),'') +
                            ', Sku= ' + ISNULL(RTRIM(@c_Sku),'') +
                            ', Facility= ' + ISNULL(RTRIM(@c_Facility),'') +
                            ', Channel= ' + ISNULL(RTRIM(@c_Channel),'') +
                            ', Lot= ' + ISNULL(RTRIM(@c_Lot),'') +
                            ': Channel Attribute Configuration Not Found! (ispCHNLHLD02)'
         GOTO QUIT_SP
   END       

   SELECT @c_SQL =
          N'SELECT TOP 1 @c_C_Attribute01 = ' +
          CASE
               WHEN ISNULL(RTRIM(@c_C_AttributeLbl01) ,'')<>'' THEN 'LA.'+@c_C_AttributeLbl01
               ELSE ''''''
          END + ', @c_C_Attribute02 = ' +
          CASE
               WHEN ISNULL(RTRIM(@c_C_AttributeLbl02) ,'')<>'' THEN 'LA.'+@c_C_AttributeLbl02
               ELSE ''''''
          END + ', @c_C_Attribute03 = ' +
          CASE
               WHEN ISNULL(RTRIM(@c_C_AttributeLbl03) ,'')<>'' THEN 'LA.'+@c_C_AttributeLbl03
               ELSE ''''''
          END + ', @c_C_Attribute04 = ' +
          CASE
               WHEN ISNULL(RTRIM(@c_C_AttributeLbl04) ,'')<>'' THEN 'LA.'+@c_C_AttributeLbl04
               ELSE ''''''
          END + ',  @c_C_Attribute05 = ' +
          CASE
               WHEN ISNULL(RTRIM(@c_C_AttributeLbl05) ,'')<>'' THEN 'LA.'+@c_C_AttributeLbl05
               ELSE ''''''
          END + '
          FROM LOTATTRIBUTE AS LA WITH (NOLOCK)
          WHERE  LA.LOT = @c_LOT '

   EXEC sp_ExecuteSQL @c_SQL,
    N' @c_LOT                  NVARCHAR(10)
      ,@c_C_Attribute01        NVARCHAR(30) OUTPUT
      ,@c_C_Attribute02        NVARCHAR(30) OUTPUT
      ,@c_C_Attribute03        NVARCHAR(30) OUTPUT
      ,@c_C_Attribute04        NVARCHAR(30) OUTPUT
      ,@c_C_Attribute05        NVARCHAR(30) OUTPUT',
       @c_LOT
      ,@c_C_Attribute01  OUTPUT
      ,@c_C_Attribute02  OUTPUT
      ,@c_C_Attribute03  OUTPUT
      ,@c_C_Attribute04  OUTPUT
      ,@c_C_Attribute05  OUTPUT

   IF @c_Channel = 'aCommerce'
   BEGIN
   	  SET @c_Condition = ' AND LOC.HostWHCode IN (''aBL'',''aQI'') '
   END
   ELSE 
   BEGIN
   	  SET @c_Condition = ' AND LOC.HostWHCode IN (SELECT Code FROM CODELKUP (NOLOCK) WHERE Listname = ''ADSTKSTS'' AND Storerkey = @c_Storerkey AND Long IN(''B'',''I'')) '
   END   

   --SELECT @n_Qty = SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)
   SELECT @c_SQL = N'
   SELECT @n_Qty = SUM(LLI.Qty)
   FROM LOTXLOCXID LLI (NOLOCK)
   JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
   JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
   WHERE LLI.Storerkey = @c_Storerkey
   AND LLI.Sku = @c_Sku
   AND LOC.Facility = @c_Facility ' + 
   @c_Condition + 
   CASE WHEN ISNULL(@c_C_AttributeLbl01,'') <> '' THEN ' AND LA.' + RTRIM(LTRIM(@c_C_AttributeLbl01)) + ' = @c_C_Attribute01 ' ELSE '' END +
   CASE WHEN ISNULL(@c_C_AttributeLbl02,'') <> '' THEN ' AND LA.' + RTRIM(LTRIM(@c_C_AttributeLbl02)) + ' = @c_C_Attribute02 ' ELSE '' END +
   CASE WHEN ISNULL(@c_C_AttributeLbl03,'') <> '' THEN ' AND LA.' + RTRIM(LTRIM(@c_C_AttributeLbl03)) + ' = @c_C_Attribute03 ' ELSE '' END +
   CASE WHEN ISNULL(@c_C_AttributeLbl04,'') <> '' THEN ' AND LA.' + RTRIM(LTRIM(@c_C_AttributeLbl04)) + ' = @c_C_Attribute04 ' ELSE '' END +
   CASE WHEN ISNULL(@c_C_AttributeLbl05,'') <> '' THEN ' AND LA.' + RTRIM(LTRIM(@c_C_AttributeLbl05)) + ' = @c_C_Attribute05 ' ELSE '' END 

   EXEC sp_ExecuteSQL @c_SQL,
      N' @c_Storerkey            NVARCHAR(15)
        ,@c_Sku                  NVARCHAR(20)
        ,@c_Facility             NVARCHAR(5)
        ,@c_Channel              NVARCHAR(20)
        ,@c_C_Attribute01        NVARCHAR(30) 
        ,@c_C_Attribute02        NVARCHAR(30) 
        ,@c_C_Attribute03        NVARCHAR(30)
        ,@c_C_Attribute04        NVARCHAR(30)
        ,@c_C_Attribute05        NVARCHAR(30)
        ,@n_Qty                  INT OUTPUT',
       @c_Storerkey
      ,@c_Sku
      ,@c_Facility
      ,@c_Channel
      ,@c_C_Attribute01
      ,@c_C_Attribute02
      ,@c_C_Attribute03
      ,@c_C_Attribute04
      ,@c_C_Attribute05
      ,@n_Qty OUTPUT
      
   IF ISNULL(@n_Qty,0) > 0
      SET @n_ChannelHoldQty = @n_Qty
       
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispCHNLHLD02'		
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END  

GO