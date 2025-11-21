SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispSHPMO04                                            */
/* Creation Date: 23-NOV-2018                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-6214 CN UA Ship combine order update child order status    */
/*                                                                         */
/*                                                                         */
/* Called By: MBOL Ship Storerconfig: PostMBOLShipSP                       */
/*                                                                         */
/*                                                                         */
/* GitLab Version: 1.2                                                     */
/*                                                                         */
/* Version: 6.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author   Ver   Purposes                                    */
/* 2019-09-21   TLTING01 1.1  Update Editdate                              */
/* 2020-10-13   WLChooi  1.2  WMS-15467 - Modify Logic (WL01)              */
/***************************************************************************/  
CREATE PROC [dbo].[ispSHPMO04]  
(     @c_MBOLkey     NVARCHAR(10)   
  ,   @c_Storerkey   NVARCHAR(15)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug     INT
         , @n_Continue  INT 
         , @n_StartTCnt INT 
         , @c_ChildOrderkey   NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5) 
         , @c_Method          NVARCHAR(10) = ''   --WL01
         , @c_SplitOrderkey   NVARCHAR(10) = ''   --WL01

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  

   IF @@TRANCOUNT = 0
      BEGIN TRAN         

   --WL01 START
   --DECLARE cur_shiporder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   --SELECT DISTINCT CHILD.Orderkey
   --FROM MBOL MB (NOLOCK)
   --JOIN MBOLDETAIL MD (NOLOCK) ON MB.Mbolkey = MD.Mbolkey
   --JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
   --JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
   --JOIN ORDERS CHILD (NOLOCK) ON OD.ConsoOrderkey = CHILD.Orderkey AND OD.Storerkey = CHILD.Storerkey
   --WHERE MB.Mbolkey = @c_Mbolkey
   ----AND O.Status = '9'
   
   DECLARE cur_shiporder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT CHILD.Orderkey, O.OrderKey, 'COMBINE'  
   FROM MBOL MB (NOLOCK)  
   JOIN MBOLDETAIL MD (NOLOCK) ON MB.Mbolkey = MD.Mbolkey  
   JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
   JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey  
   JOIN ORDERS CHILD (NOLOCK) ON OD.ConsoOrderkey = CHILD.Orderkey AND OD.Storerkey = CHILD.Storerkey  
   WHERE MB.Mbolkey = @c_Mbolkey  
   UNION ALL  
   SELECT DISTINCT ORIO.Orderkey, O.OrderKey, 'SPLIT'  
   FROM MBOL MB (NOLOCK)    
   JOIN MBOLDETAIL MD (NOLOCK) ON MB.Mbolkey = MD.Mbolkey    
   JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey    
   JOIN ORDERS ORIO (NOLOCK) ON O.POKey = ORIO.OrderKey  
   WHERE MB.Mbolkey = @c_MBOLkey  
   --AND NOT EXISTS (SELECT 1 FROM ORDERDETAIL ORIOD (NOLOCK)   
   --                INNER JOIN ORDERS SPLO (NOLOCK) ON SPLO.OrderKey = ORIOD.ConsoOrderKey   
   --                WHERE ORIOD.OrderKey=ORIO.OrderKey AND SPLO.[Status] <> '9' AND SPLO.MBOLKey <> @c_MBOLkey)    --Josh Remove because all split order need update original orderdetail 
   --WL01 END  

   OPEN cur_shiporder  
      
   FETCH NEXT FROM cur_shiporder INTO @c_ChildOrderkey, @c_SplitOrderkey, @c_Method   --WL01
           
   WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
   BEGIN
      DECLARE cur_orddet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderLineNumber
      FROM ORDERDETAIL (NOLOCK)   	        
      WHERE Orderkey = @c_ChildOrderkey
      AND ConsoOrderKey = @c_SplitOrderkey  --Josh for combine order, child ordertail only have one value, for original order, value is split order key
      AND Status NOT IN ('9','CANC')

      OPEN cur_orddet  
       
      FETCH NEXT FROM cur_orddet INTO @c_OrderLineNumber
           
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN   	       
         UPDATE ORDERDETAIL WITH (ROWLOCK)  
         SET [STATUS]   = '9',   --WL01                     
             Trafficcop = NULL,  
             Editdate   = getdate(),   -- tlting01  
             Editwho    = Suser_Sname()    --tlting01  
         WHERE Orderkey = @c_ChildOrderkey  
         AND OrderLineNumber = @c_OrderLineNumber  
            
         SET @n_err = @@ERROR    
         
         IF @n_err <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @n_err = 61900-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Update Failed On Table ORDERDETAIL. (ispSHPMO04)'            
         END   
            
         FETCH NEXT FROM cur_orddet INTO @c_OrderLineNumber
         END   
         CLOSE cur_orddet
         DEALLOCATE cur_orddet 	   	 	        	 
      	
      	--WL01 START  
         IF @c_Method = 'COMBINE'  
         BEGIN  
            UPDATE ORDERS WITH (ROWLOCK)  
            SET [STATUS]   = '9',  
                SoStatus   = '9',                     
                Trafficcop = NULL,  
                Editdate   = getdate(),   -- tlting01  
                Editwho    = Suser_Sname()    --tlting01  
             WHERE Orderkey = @c_ChildOrderkey  
             AND Status NOT IN ('9','CANC')      
         END      
         ELSE  
         BEGIN  
            IF NOT EXISTS (SELECT 1 FROM ORDERDETAIL ORIOD (NOLOCK)   
                           INNER JOIN ORDERS SPLO (NOLOCK) ON SPLO.OrderKey = ORIOD.ConsoOrderKey   
                           WHERE ORIOD.OrderKey = @c_ChildOrderkey AND SPLO.[Status] <> '9' AND SPLO.MBOLKey <> @c_MBOLkey)  --Josh Check this original order all split order is shipped or in same mbol
            BEGIN
               UPDATE ORDERS WITH (ROWLOCK)  
               SET [STATUS]   = '9',  
                   SoStatus   = '9'                     
               WHERE Orderkey = @c_ChildOrderkey  
               AND Status NOT IN ('9','CANC')    
            END
         END  
         --WL01 END  

         SET @n_err = @@ERROR    
         
         IF @n_err <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @n_err = 61910-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Update Failed On Table ORDERS. (ispSHPMO04)'            
         END    	   	 	  
                     
         FETCH NEXT FROM cur_shiporder INTO @c_ChildOrderkey, @c_SplitOrderkey, @c_Method   --WL01
      END
      --CLOSE cur_shiporder   --WL01
      --DEALLOCATE cur_shiporder   --WL01

QUIT_SP:
   --WL01 START
   IF CURSOR_STATUS('LOCAL', 'cur_shiporder') IN (0 , 1)
   BEGIN
      CLOSE cur_shiporder
      DEALLOCATE cur_shiporder   
   END
   --WL01 END
   
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispSHPMO04'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO