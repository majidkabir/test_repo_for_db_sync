SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispRVORD01                                         */
/* Creation Date: 07-09-2015                                            */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#354321 - Lululemon - Reverse Orders Combined            */
/*                                                                      */
/* Called By: PB object - n_cst_order EVENT ue_revcombineorder          */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispRVORD01]
   @c_OrderKey       NVARCHAR(10)
,  @b_Success        INT            OUTPUT
,  @n_Err            INT            OUTPUT
,  @c_ErrMsg         NVARCHAR(250)  OUTPUT 
AS  
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE 
         @n_Starttcnt         INT   
      ,  @n_Continue          INT   
      ,  @b_Debug             INT

      ,  @c_OrderLineNumber   NVARCHAR(5)
      ,  @c_RevToOrderkey     NVARCHAR(10)
      ,  @c_RevToLineNo       NVARCHAR(5)

   SET @b_Success   = 0 
   SET @n_Continue  = 1 
   SET @n_Starttcnt = @@TRANCOUNT 
   SET @b_Debug     = 0


   IF NOT EXISTS  (  SELECT 1
                     FROM ORDERDETAIL WITH (NOLOCK) 
                     WHERE OrderKey = @c_OrderKey
                     AND ExternConsoOrderkey <> '' 
                     AND ExternConsoOrderkey IS NOT NULL
                   ) 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65000
      SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Order ' + RTRIM(@c_OrderKey) +' Not a Combined Order. (ispRVORD01)'
      GOTO QUIT
   END

   IF EXISTS(SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK) 
             WHERE OrderKey = @c_OrderKey)
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65005
      SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Order ' + RTRIM(@c_OrderKey) + ' Already Populated to Load Plan. (ispRVORD01)'
      GOTO QUIT      
   END

   IF EXISTS(SELECT 1 FROM WAVEDETAIL WITH (NOLOCK) 
             WHERE OrderKey = @c_OrderKey)
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65010
      SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Order ' + RTRIM(@c_OrderKey) + ' Already Populated to Wave. (ispRVORD01)'
      GOTO QUIT      
   END

   IF EXISTS(SELECT 1 FROM MBOLDETAIL WITH (NOLOCK) 
             WHERE OrderKey = @c_OrderKey)
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 65015
      SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Order ' + RTRIM(@c_OrderKey) + ' Already Populated to MBOL. (ispRVORD01)'
      GOTO QUIT      
   END
      
   BEGIN TRAN
     
   IF (@n_Continue = 1 OR @n_Continue = 2) -- Perform Updates
   BEGIN
      -- Loop thru each FromLoad detail lines, update detail lines
      DECLARE ORDERDET_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderLineNumber
            ,ExternConsoOrderkey
            ,ConsoOrderLineNo
      FROM   ORDERDETAIL WITH (NOLOCK)
      WHERE  OrderKey = @c_OrderKey
      AND    ExternConsoOrderkey <> ''
      AND    ExternConsoOrderkey IS NOT NULL
      AND    ConsoOrderLineNo <> ''
      AND    ConsoOrderLineNo IS NOT NULL
      ORDER BY OrderLineNumber
      
      OPEN ORDERDET_CUR
   
      FETCH NEXT FROM ORDERDET_CUR INTO @c_OrderLineNumber
                                       ,@c_RevToOrderkey
                                       ,@c_RevToLineNo
   
      WHILE @@FETCH_STATUS <> -1 AND (@n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         -- Increase LineNo by 1
         
         UPDATE ORDERDETAIL WITH (ROWLOCK)
         SET   OrderKey        = @c_RevToOrderkey 
             , OrderLineNumber = @c_RevToLineNo 
             , ExternConsoOrderKey = '' 
             , ConsoOrderLineNo= ''  
             , EditWho         = sUser_sName()
             , EditDate        = GetDate() 
             , TrafficCop      = NULL
         WHERE OrderKey        = @c_OrderKey
         AND   OrderLineNumber = @c_OrderLineNumber

         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 65020
            SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Update Failed On Table ORDERDETAIL. (ispRVORD01)'
         END

         UPDATE ORDERS WITH (ROWLOCK)
         SET   Status    = '0',
               SOStatus  = '0',
               EditWho   = sUser_sName(),
               EditDate  = GetDate(),
               Trafficcop= NULL
         WHERE OrderKey  = @c_RevToOrderkey 

         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 65025
            SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Update Failed On Table ORDERDETAIL. (ispRVORD01)'
         END

         FETCH NEXT FROM ORDERDET_CUR INTO @c_OrderLineNumber
                                          ,@c_RevToOrderkey
                                          ,@c_RevToLineNo
      END
      CLOSE ORDERDET_CUR
      DEALLOCATE ORDERDET_CUR
   END 
   
   QUIT:
   -- Error Occured - Process And Return
   IF @n_Continue=3
   BEGIN
      SET @b_Success = 0    
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

      EXECUTE nsp_LogError @n_Err, @c_ErrMsg, 'ispRVORD01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO