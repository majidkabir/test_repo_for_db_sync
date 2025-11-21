SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF06                                            */
/* Creation Date: 02-OCT-2017                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-3043 CN Yankee Candle - Pack confirm update packinginfo    */
/*          for single item carton                                         */
/*          Storerconfig PostPackConfirmSP='ispPAKCF06'                    */
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispPAKCF06]  
(     @c_PickSlipNo  NVARCHAR(10)   
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
  
   DECLARE @b_Debug        INT,
           @n_Continue     INT,
           @n_StartTCnt    INT, 
           @n_CartonNo     INT,
           @c_CartonType   NVARCHAR(10),
           @n_CartonWeight FLOAT,
           @n_CartonLength FLOAT,
           @n_CartonWidth  FLOAT,
           @n_CartonHeight FLOAT,
           @n_CartonCube   FLOAT

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug  = 0 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
                      
   DECLARE CUR_PACKCTN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                        
      SELECT PKD.PickSlipNo, PKD.CartonNo, CZ2.Cartontype, CZ2.MaxWeight, CZ2.CartonLength, CZ2.CartonWidth, CZ2.CartonHeight, CZ2.[Cube]
      FROM PACKDETAIL PKD (NOLOCK)
      JOIN SKU (NOLOCK) ON PKD.Storerkey = SKU.Storerkey AND PKD.Sku = SKU.Sku
      JOIN STORER (NOLOCK) ON PKD.StorerKey = STORER.StorerKey
      LEFT JOIN PACKINFO PKI (NOLOCK) ON PKD.PickSlipNo = PKI.PickSlipNo AND PKD.CartonNo = PKI.CartonNo
      LEFT JOIN CARTONIZATION CZ1 (NOLOCK) ON STORER.CartonGroup = CZ1.CartonizationGroup AND CZ1.UseSequence = 1 --storer cartongroup
      LEFT JOIN CARTONIZATION CZ2 (NOLOCK) ON SKU.CartonGroup = CZ2.CartonizationGroup AND CZ2.UseSequence = 1 --sku cartongroup
      WHERE ISNULL(CZ2.CartonType,'') <> '' --Sku carton type is setup
      AND (CZ1.CartonType = PKI.CartonType  --packinfo with default carton type
           OR ISNULL(PKI.CartonType,'') = ''   --Not capture packinfo yet or carton type is empty
           OR CZ1.CartonType IS NULL)  --Storer default carton type not setup
      AND ISNULL(CZ2.CartonType,'') <> ISNULL(PKI.CartonType,'') --if sku carton type is different than packinfo    
      AND PKD.Pickslipno = @c_Pickslipno
      GROUP BY PKD.PickSlipNo, PKD.CartonNo, CZ2.Cartontype, CZ2.MaxWeight, CZ2.CartonLength, CZ2.CartonWidth, CZ2.CartonHeight, CZ2.[Cube]
      HAVING COUNT(DISTINCT PKD.SKU) = 1 --only single sku carton
      ORDER BY PKD.CartonNo

   OPEN CUR_PACKCTN  
   
   FETCH NEXT FROM CUR_PACKCTN INTO @c_Pickslipno, @n_CartonNo, @c_CartonType, @n_CartonWeight, @n_CartonLength, @n_CartonWidth, @n_CartonHeight, @n_CartonCube   
   
   WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
   BEGIN
   	
   	  IF NOT EXISTS(SELECT 1 FROM PACKINFO(NOLOCK) WHERE Pickslipno = @c_Pickslipno AND CartonNo = @n_Cartonno)
   	  BEGIN
   	     INSERT INTO PACKINFO (Pickslipno, CartonNo, CartonType, Weight, Length, Width, Height, [Cube])
   	     VALUES (@c_Pickslipno, @n_CartonNo, @c_CartonType, @n_CartonWeight, @n_CartonLength, @n_CartonWidth, @n_CartonHeight, @n_CartonCube)
   	     
	       SET @n_Err = @@ERROR
	                          
         IF @n_Err <> 0
         BEGIN
         	  SELECT @n_Continue = 3 
	          SELECT @n_Err = 38010
	          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Insert PACKINFO Failed. (ispPAKCF06)'
         END   	 	      	      
   	  END
   	  ELSE
   	  BEGIN
   	     UPDATE PACKINFO WITH (ROWLOCK)
   	     SET CartonType = @c_CartonType, 
   	         Weight = @n_CartonWeight, 
   	         Length = @n_CartonLength, 
   	         Width = @n_CartonWidth, 
   	         Height = @n_CartonHeight,
   	         [Cube] =  @n_CartonCube
   	     WHERE PickslipNo = @c_Pickslipno
   	     AND CartonNo = @n_CartonNo

	       SET @n_Err = @@ERROR
	                          
         IF @n_Err <> 0
         BEGIN
         	  SELECT @n_Continue = 3 
	          SELECT @n_Err = 38020
	          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update PACKINFO Failed. (ispPAKCF06)'
         END   	 	      	      
   	  END
   	
      FETCH NEXT FROM CUR_PACKCTN INTO @c_Pickslipno, @n_CartonNo, @c_CartonType, @n_CartonWeight, @n_CartonLength, @n_CartonWidth, @n_CartonHeight, @n_CartonCube   
   END
   CLOSE CUR_PACKCTN         
   DEALLOCATE CUR_PACKCTN
      
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF06'
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