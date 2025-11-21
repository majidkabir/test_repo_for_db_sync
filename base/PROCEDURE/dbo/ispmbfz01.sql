SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispMBFZ01                                             */
/* Creation Date: 24-FEB-2017                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-988 - CN Charming Charlie MBOL Finalize split load plan    */
/*                    by consignee for interface                           */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispMBFZ01]  
(     @c_MBOLKey  NVARCHAR(10)   
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
      
   DECLARE @n_Continue INT,
           @n_StartTranCount INT,
           @c_Loadkey NVARCHAR(10),    
           @c_ToLoadkey NVARCHAR(10),    
           @c_Orderkey NVARCHAR(10),
           @c_Consigneekey NVARCHAR(15),
		   @c_LoadLineNumber NVARCHAR(5)
           
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT              

   IF @n_continue IN (1,2)
   BEGIN   	
      UPDATE MBOLDETAIL WITH (ROWLOCK)
      SET MBOLDETAIL.Userdefine01 = ORDERS.Loadkey
      FROM MBOLDETAIL
      JOIN ORDERS (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey
      WHERE MBOLDETAIL.MBOLKey = @c_MBOLKey
      
      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 62510
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update MBOLDETAIL Table Failed! (ispMBFZ01)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP                                
      END
  END

   IF @n_continue IN (1,2)
   BEGIN   	
   	  --Get consignee from mbol
      DECLARE CUR_CONSIGNEE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT O.Consigneekey
         FROM MBOLDETAIL MD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
         WHERE MD.Mbolkey = @c_MBOLKey
         GROUP BY O.Consigneekey
         ORDER BY O.Consigneekey

      OPEN CUR_CONSIGNEE  
         
      FETCH NEXT FROM CUR_CONSIGNEE INTO  @c_Consigneekey      

      WHILE @@FETCH_STATUS = 0  
      BEGIN   
      	 SELECT @c_ToLoadkey = '' --every consignee create new load
      	 
      	 --Get order and load plan of the consignee and move to new load plan
         DECLARE CUR_CONSORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT O.Orderkey, LD.Loadkey, LD.LoadLineNumber
            FROM MBOLDETAIL MD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
            JOIN LOADPLANDETAIL LD (NOLOCK) ON O.Orderkey = LD.Orderkey
            WHERE MD.Mbolkey = @c_MBOLKey
            AND O.Consigneekey = @c_Consigneekey
            GROUP BY O.Orderkey, LD.Loadkey, LD.LoadLineNumber
            ORDER BY LD.Loadkey, LD.LoadLineNumber
         
         OPEN CUR_CONSORDER  
            
         FETCH NEXT FROM CUR_CONSORDER INTO @c_Orderkey, @c_Loadkey, @c_LoadLineNumber             
           
         WHILE @@FETCH_STATUS = 0  
         BEGIN   
         	 
         	  EXEC dbo.isp_MoveOrderToLoad 
         	       @c_Loadkey = @c_Loadkey
         	      ,@c_LoadLineNumber = @c_LoadLineNumber
         	      ,@c_ToLoadkey = @c_ToLoadkey OUTPUT
                ,@b_Success = @b_Success   OUTPUT
                ,@n_Err = @n_Err       OUTPUT
                ,@c_ErrMsg = @c_ErrMsg    OUTPUT   

            IF @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 62520
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Move Load Plan Failed! (ispMBFZ01)' + ' ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO QUIT_SP                                
            END
         	  
            FETCH NEXT FROM CUR_CONSORDER INTO @c_Orderkey, @c_Loadkey, @c_LoadLineNumber               
         END
         CLOSE CUR_CONSORDER  
         DEALLOCATE CUR_CONSORDER                                              	        
      	 
         FETCH NEXT FROM CUR_CONSIGNEE INTO  @c_Consigneekey
      END
      CLOSE CUR_CONSIGNEE  
      DEALLOCATE CUR_CONSIGNEE                                              	                    
   END
   
   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispMBFZ01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO