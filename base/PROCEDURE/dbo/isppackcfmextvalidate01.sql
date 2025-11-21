SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPackCFMExtValidate01                                 */
/* Creation Date: 2021-07-27                                            */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-17491 - SG Prestige - AD Scanning validation            */
/*        :                                                             */
/* Called By: Pack confirm extend validation                            */
/*          : isp_Pack_ExtendedValidation                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispPackCFMExtValidate01]
           @c_Pickslipno NVARCHAR(10), 
           @c_StorerKey NVARCHAR(15), 
           @b_Success Int OUTPUT,
           @n_Err Int OUTPUT, 
           @c_ErrMsg NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt              INT 
         , @n_Continue               INT 
         , @n_CaseCnt                INT
         , @n_CartonNo               INT  
         , @c_Facility               NVARCHAR(5)
         , @c_C_Country              NVARCHAR(30)
         , @c_Sku                    NVARCHAR(20)
         , @c_Orderkey               NVARCHAR(10)
         , @c_PackByCase             NVARCHAR(5)
         , @n_Qty                    INT
         , @c_LottableValue          NVARCHAR(60)
         , @n_TotSerialNo            INT 
         , @n_TotCarton              INT
         , @n_TotPiece               INT
         , @c_AntiDiversionByCaseCnt NVARCHAR(30)

   SELECT @b_Success = 1, @n_Err = 0, @c_Errmsg = '', @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1
    
   SELECT @c_Facility = O.Facility,
          @c_c_Country = O.C_Country
   FROM PACKHEADER PKH (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON PKH.Orderkey = O.Orderkey
   WHERE PKH.Pickslipno = @c_Pickslipno
   
   IF ISNULL(@c_Facility,'') = ''
   BEGIN   	
      SELECT TOP 1 @c_Facility = O.Facility,
             @c_c_Country = O.C_Country
      FROM PACKHEADER PKH (NOLOCK)
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON PKH.Loadkey = LPD.Loadkey
      JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
      WHERE PKH.Pickslipno = @c_Pickslipno   	
   END
      
   SELECT @c_AntiDiversionByCaseCnt = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AntiDiversionByCaseCnt')  
     
   IF @n_continue IN(1,2)
   BEGIN
   	  DECLARE CUR_CARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	     SELECT PKD.CartonNo, PKH.Orderkey
   	     FROM PACKHEADER PKH (NOLOCK)
   	     JOIN PACKDETAIL PKD (NOLOCK) ON PKH.Pickslipno = PKD.Pickslipno
   	     JOIN SKU (NOLOCK) ON PKD.Storerkey = SKU.Storerkey AND PKD.Sku = SKU.Sku
   	     WHERE PKH.Pickslipno = @c_Pickslipno
   	     AND SKU.Susr4 = 'AD' 
   	     AND @c_C_Country IN('SG','Singapore')
   	     GROUP BY PKD.CartonNo, PKH.Orderkey
   	     ORDER BY PKD.CartonNo

      OPEN CUR_CARTON  
         
      FETCH NEXT FROM CUR_CARTON INTO @n_Cartonno, @c_Orderkey      
         
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN         
         DECLARE CUR_CTNSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PKD.Sku, PACK.Casecnt, CASE WHEN @c_AntiDiversionByCaseCnt = '1' AND CL.Code IS NULL THEN 'Y' ELSE 'N' END
   	        FROM PACKHEADER PKH (NOLOCK)
   	        JOIN PACKDETAIL PKD (NOLOCK) ON PKH.Pickslipno = PKD.Pickslipno
   	        JOIN SKU (NOLOCK) ON PKD.Storerkey = SKU.Storerkey AND PKD.Sku = SKU.Sku
   	        JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
   	        LEFT JOIN CODELKUP CL (NOLOCK) ON SKU.Busr6 = CL.Code AND CL.ListName = 'PRESTGADEA'
   	        WHERE PKH.Pickslipno = @c_Pickslipno
     	      AND SKU.Susr4 = 'AD' 
     	      AND PKD.CartonNo = @n_CartonNo   	        
   	        GROUP BY PKD.Sku, PACK.Casecnt, CL.Code    
   	        ORDER BY PKD.Sku, PACK.Casecnt

         OPEN CUR_CTNSKU  
            
         FETCH NEXT FROM CUR_CTNSKU INTO @c_Sku, @n_Casecnt, @c_PackByCase      
            
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN           
   	        SET @n_TotCarton = 0
   	        SET @n_TotPiece = 0 
   	        SET @n_TotSerialNo = 0

            DECLARE CUR_CTNLOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PKD.LottableValue, SUM(PKD.Qty)
   	           FROM PACKHEADER PKH (NOLOCK)
   	           JOIN PACKDETAIL PKD (NOLOCK) ON PKH.Pickslipno = PKD.Pickslipno
   	           JOIN SKU (NOLOCK) ON PKD.Storerkey = SKU.Storerkey AND PKD.Sku = SKU.Sku
   	           JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
   	           WHERE PKH.Pickslipno = @c_Pickslipno
     	         AND SKU.Sku = @c_Sku
     	         AND PKD.CartonNo = @n_CartonNo   	        
   	           GROUP BY PKD.LottableValue   	     
   	           ORDER BY PKD.LottableValue

            OPEN CUR_CTNLOT  
            
            FETCH NEXT FROM CUR_CTNLOT INTO @c_LottableValue, @n_Qty      
   	         
   	        WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
            BEGIN   
            	 IF @c_PackByCase = 'Y' AND @n_Casecnt > 0
            	 BEGIN
            	    SET @n_TotCarton = @n_TotCarton + FLOOR(@n_Qty / @n_CaseCnt)
            	    SET @n_TotPiece = @n_TotPiece + (@n_Qty % @n_CaseCnt)
            	 END
            	 ELSE
            	 BEGIN
            	 	  SET @n_TotPiece = @n_TotPiece + @n_Qty
            	 END   
            	 
               FETCH NEXT FROM CUR_CTNLOT INTO @c_LottableValue, @n_Qty      
            END                                        
            CLOSE CUR_CTNLOT
            DEALLOCATE CUR_CTNLOT
            
            SELECT @n_TotSerialNo = COUNT(1)
            FROM SERIALNO (NOLOCK)
            WHERE Orderkey = @c_Orderkey
            AND OrderLineNumber = LTRIM(RTRIM(CAST(@n_CartonNo AS NVARCHAR)))
            AND Storerkey = @c_Storerkey
            AND Sku = @c_Sku
            
            IF @n_TotSerialNo <> (@n_TotCarton + @n_TotPiece)
            BEGIN
               SET @n_continue = 3  
               SET @n_err = 70000   
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Serial# not tally at Carton: ' + LTRIM(RTRIM(CAST(@n_CartonNo AS NVARCHAR))) + ' Sku: ' + RTRIM(@c_Sku) + 
                   ' Total Serial# : ' + LTRIM(RTRIM(CAST(@n_TotSerialNo AS NVARCHAR))) + 'Total Case: ' + LTRIM(RTRIM(CAST(@n_TotCarton AS NVARCHAR))) + 
                   ' Total Piece: ' + LTRIM(RTRIM(CAST(@n_TotPiece AS NVARCHAR))) + ' (ispPackCFMExtValidate01)'   
            END
                     	
            FETCH NEXT FROM CUR_CTNSKU INTO @c_Sku, @n_Casecnt, @c_PackByCase      
         END 	               
         CLOSE CUR_CTNSKU
         DEALLOCATE CUR_CTNSKU
   	              	 
         FETCH NEXT FROM CUR_CARTON INTO @n_Cartonno, @c_Orderkey      
      END
      CLOSE CUR_CARTON
      DEALLOCATE CUR_CARTON   	        	         	  	     
   END 
    
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPackCFMExtValidate01'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO