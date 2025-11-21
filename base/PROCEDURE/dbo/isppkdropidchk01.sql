SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPKDROPIDCHK01                                   */
/* Creation Date: 13-Aug-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-10048 SG THG Pack DropID validation                     */   
/*                                                                      */
/* Called By: Packing lottable -> isp_PackDropIDCheck_Wrapper           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/

CREATE PROC [dbo].[ispPKDROPIDCHK01]    
   @c_Storerkey     NVARCHAR(15),
   @c_Facility      NVARCHAR(5),
   @c_DropID        NVARCHAR(20),
   @b_Success       INT           OUTPUT,
   @n_Err           INT           OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue           INT,
           @n_StartTCnt          INT,
           @c_Orderkey           NVARCHAR(10),
           @c_OrderLineNumber    NVARCHAR(5),
           @c_Lot                NVARCHAR(10)
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 
	 IF ISNULL(@c_DropID,'') = ''
	    GOTO QUIT_SP
	 
	 IF EXISTS (SELECT 1
	            FROM PICKDETAIL PD (NOLOCK)
              JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
              LEFT JOIN PACKHEADER PH (NOLOCK) ON PD.Orderkey = PH.Orderkey          
              WHERE PD.DropID = @c_DropID   
              AND PD.Storerkey = @c_Storerkey
              AND PD.Status <> '9'
              AND PH.Pickslipno IS NULL
              HAVING COUNT(DISTINCT O.Userdefine09) > 1
              )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61900-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
      SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Found the DropID: ' + RTRIM(ISNULL(@c_Dropid,'')) + ' Exists in more than one pending wave. (ispPKDROPIDCHK01 )'   	 	 
      GOTO QUIT_SP
   END           
   
   SELECT TOP 1 @c_Orderkey = PD.Orderkey, 
                @c_OrderLineNumber = PD.OrderLineNumber,
                @c_Lot = PD.Lot
	 FROM PICKDETAIL PD (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
   JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
   LEFT JOIN PACKHEADER PH (NOLOCK) ON PD.Orderkey = PH.Orderkey              
   WHERE PD.DropID = @c_DropID   
   AND PD.Storerkey = @c_Storerkey
   AND PD.Status <> '9'
   AND PH.PickslipNo IS NULL
   AND LA.Lottable04 IS NOT NULL
   AND CONVERT(NVARCHAR(8), LA.Lottable04, 112) <> '19000101'
   AND DATEDIFF(Day, GETDATE(), LA.Lottable04) <= 0
   ORDER BY PD.Orderkey, PD.OrderLineNumber
      	 
	 IF ISNULL(@c_Orderkey,'') <> ''
	 BEGIN
      SET @n_continue = 3    
      SET @n_err = 61910-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
      SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Found expired pickdetail at Orderkey: ' + RTRIM(ISNULL(@c_Orderkey,'')) + 
          ' Line Number: ' + RTRIM(ISNULL(@c_OrderLineNumber,'')) + ' Lot: ' + RTRIM(ISNULL(@c_Lot,'')) +'. (ispPKDROPIDCHK01 )'   	 	 
      GOTO QUIT_SP
	 END
	 	   
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKDROPIDCHK01 '		
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