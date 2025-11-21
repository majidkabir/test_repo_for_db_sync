SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_ContainerPalletMove                            */  
/* Creation Date: 15-Aug-2017                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-1880 SG MHAP Build container - Pallet Move              */  
/*                                                                      */ 
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:  @b_Success                                       */
/*                   , @n_err                                           */
/*                   , @c_errmsg                                        */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */ 
/* Called By: Container RCM Move Pallet                                 */
/*            w_popup_container_move_pallet                             */
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

CREATE PROC [dbo].[isp_ContainerPalletMove] 
   @c_FromContainerkeys NVARCHAR(MAX),
   @c_Palletkeys        NVARCHAR(MAX),
   @c_ToContainerkey    NVARCHAR(10),
   @b_Success           INT OUTPUT, 
   @n_err               INT OUTPUT, 
   @c_errmsg            NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @n_continue           INT,
           @n_StartTCnt          INT,
           @n_LineNo             INT,
           @c_LineNo             NVARCHAR(5),
           @c_FromContainerkey   NVARCHAR(10),                      
           @c_Palletkey          NVARCHAR(30)           
   
   SELECT @n_StartTCnt =  @@TRANCOUNT, @n_continue  = 1, @n_err = 0, @c_Errmsg = '', @b_success = 1

   IF @n_continue IN(1,2)
   BEGIN
   	  SELECT CONTAINER.ColValue AS ContainerKey, PALLET.ColValue AS Palletkey 
      INTO #TMP_PALLET
      FROM dbo.fnc_DelimSplit(',', @c_FromContainerkeys) AS Container
      JOIN dbo.fnc_DelimSplit(',', @c_Palletkeys) AS Pallet ON CONTAINER.SeqNo = PALLET.SeqNo   	
      
      SET @c_FromContainerkey = ''
      SET @c_Palletkey = ''
      SELECT TOP 1 @c_FromContainerkey = TP.Containerkey,
                   @c_Palletkey = TP.Palletkey 
      FROM #TMP_PALLET TP
      LEFT JOIN CONTAINERDETAIL CD (NOLOCK) ON TP.Containerkey = CD.Containerkey AND TP.Palletkey = CD.Palletkey
      WHERE CD.Palletkey IS NULL

   	  IF ISNULL(@c_Palletkey,'') <> ''
   	  BEGIN
   		  SELECT @n_continue = 3
			  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 34100
			  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Pallet Move Failed. Pallet ' + RTRIM(@c_Palletkey) + ' No More Exist In Container ' + RTRIM(@c_FromContainerkey) + '. (isp_ContainerPalletMove)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      END       
   END   	  
      
   IF @n_continue IN(1,2)
   BEGIN   	        
      SELECT @n_LineNo = ISNULL(CAST(MAX(ContainerLineNumber) AS INT),0) 
      FROM CONTAINERDETAIL (NOLOCK)
      WHERE Containerkey = @c_ToContainerKey                  
   	   	   	
   	  DECLARE CUR_PALLET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   	  
   	     SELECT Containerkey, Palletkey
   	     FROM #TMP_PALLET
   	     ORDER BY Containerkey, Palletkey   	     
   	        	  
   	  OPEN CUR_PALLET   
      
      FETCH NEXT FROM CUR_PALLET INTO @c_FromContainerkey, @c_Palletkey

      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)             
      BEGIN      	
      	 SELECT @n_LineNo = @n_LineNo + 1
      	 SELECT @c_LineNo = RIGHT('00000' + RTRIM(LTRIM(CAST(@n_LineNo AS NVARCHAR))),5)        

         INSERT INTO CONTAINERDETAIL (Containerkey, ContainerLineNumber, Palletkey)
         VALUES (@c_ToContainerkey, @c_LineNo, @c_PalletKey)
         
  	   	 SELECT @n_err = @@ERROR
   	   	 IF @n_err <> 0
   	     BEGIN
   		     SELECT @n_continue = 3
			     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 34110
			     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert Containerdetail Table. (isp_ContainerPalletMove)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		     END               
		     
		     DELETE FROM CONTAINERDETAIL
		     WHERE Containerkey = @c_FromContainerkey
		     AND Palletkey = @c_Palletkey
		     
  	   	 SELECT @n_err = @@ERROR
   	   	 IF @n_err <> 0
   	     BEGIN
   		     SELECT @n_continue = 3
			     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 34120
			     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Delete Containerdetail Table. (isp_ContainerPalletMove)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		     END               
      	 
         FETCH NEXT FROM CUR_PALLET INTO @c_FromContainerkey, @c_Palletkey
      END
      CLOSE CUR_PALLET
      DEALLOCATE CUR_PALLET   	     	
   END   
           
   QUIT_SP:

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_ContainerPalletMove'
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR 
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
END

GO