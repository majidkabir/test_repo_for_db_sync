SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Procedure: isp_autoalloc_partial                                 */    
/* Creation Date: 15-APRIL-2022                                            */    
/* Copyright: LFL                                                          */    
/* Written by: WZPang                                                      */    
/*                                                                         */    
/* Purpose: WMS-19251 - Not Fully Allocated Orders Report                  */    
/*                                                                         */    
/* Called By: r_dw_autoalloc_partial                                       */    
/*                                                                         */    
/* GitLab Version: 1.1                                                     */    
/*                                                                         */    
/* Version: 1.0                                                            */    
/*                                                                         */    
/* Data Modifications:                                                     */    
/*                                                                         */    
/* Updates:                                                                */    
/* Date         Author  Ver   Purposes                                     */  
/* 18-Apr-2022  WLChooi 1.0   DevOps Combine Script                        */
/* 06-Apr-2023  WLChooi 1.1   WMS-22159 Extend Userdefine01 to 50 (C01)    */ 
/***************************************************************************/        
CREATE   PROC [dbo].[isp_autoalloc_partial] ( 
         @c_StorerKey   NVARCHAR(50)
       , @c_BatchNo     NVARCHAR(50)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF
   
   /*
   DECLARE @c_AllocateValidationRules NVARCHAR(30),
           @c_Facility NVARCHAR(5),
           @c_Orderkey NVARCHAR(10),
           @b_Success  INT,
           @c_ErrMsg   NVARCHAR(250),
           @c_OrderLineNumber         NVARCHAR(5),
           @n_Pos1     INT,
           @n_Pos2     INT
   */        

   CREATE TABLE #TMP_RESULT (Adddate  DATETIME NULL,
                             Orderkey NVARCHAR(10) NULL,
                             ExternOrderkey NVARCHAR(50) NULL,
                             ExternLineNo NVARCHAR(20) NULL,
                             Sku NVARCHAR(20) NULL,
                             Description NVARCHAR(250) NULL,
                             Userdefine01 NVARCHAR(50) NULL,   --C01
                             OrderLineNumber NVARCHAR(5) NULL,
                             ErrMsg NVARCHAR(500) NULL) 
   
   INSERT INTO #TMP_RESULT (Adddate, Orderkey, ExternOrderkey, ExternLineNo, Sku, Description, Userdefine01, OrderLineNumber)
   SELECT ORDERS.ADDDATE,
          ORDERS.OrderKey,
          ORDERS.ExternOrderkey,          
          OD.ExternLineNo,
          OD.SKU,
          ISNULL(CLK.Description,''),
          ORDERS.UserDefine01,
          OD.OrderLineNumber
   FROM ORDERS (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON (ORDERS.OrderKey = OD.OrderKey)
   JOIN SKU (NOLOCK) ON (SKU.SKU = OD.SKU and SKU.Storerkey = OD.Storerkey)
   LEFT JOIN CODELKUP CLK (NOLOCK) ON (CLK.listname = 'ORDRStatus' and CLK.code = OD.[STATUS])
   WHERE ORDERS.[STATUS] < '2' 
   AND ORDERS.Storerkey = @c_Storerkey 
   AND ORDERS.UserDefine01 = @c_BatchNo
   AND OD.Status < 2

   /*
   SELECT TOP 1 @c_AllocateValidationRules = SC.sValue
   FROM STORERCONFIG SC (NOLOCK)
   JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
   WHERE SC.StorerKey = @c_StorerKey
   --AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '')
   AND SC.Configkey = 'PreAllocateExtendedValidation'
   ORDER BY SC.Facility DESC
   
   IF ISNULL(@c_AllocateValidationRules,'') <> ''
   BEGIN         
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR       
         SELECT DISTINCT Orderkey
         FROM #TMP_RESULT
         ORDER BY Orderkey
      
      OPEN CUR_ORD   
         
      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
         
      WHILE @@FETCH_STATUS <> -1 
      BEGIN                           
      	 SELECT @b_Success = 1, @c_ErrMsg = '', @c_OrderLineNumber = '', @n_Pos1 = 0, @n_Pos2 = 0
      	 
         EXEC isp_Allocate_ExtendedValidation @c_Orderkey = @c_Orderkey,
                                              @c_Loadkey = '',
                                              @c_Wavekey = '',
                                              @c_Mode = 'PRE',
                                              @c_AllocateValidationRules=@c_AllocateValidationRules,
                                              @b_Success=@b_Success OUTPUT,
                                              @c_ErrMsg=@c_ErrMsg OUTPUT

         IF @b_Success <> 1
         BEGIN
         	  SELECT @n_pos1 = CHARINDEX('Line#', @c_ErrMsg)
         	  IF @n_pos1 > 0 
         	  BEGIN
         	  	 SELECT @c_OrderLineNumber = SUBSTRING(@c_ErrMsg, @n_pos1+6, 5)
         	  	 SELECT @n_Pos2 = CHARINDEX('.', @c_ErrMsg, @n_Pos1 )
         	  	 
         	  	 IF @n_pos2 > 0
         	  	 BEGIN
         	  	    SELECT @c_ErrMsg = SUBSTRING(@c_ErrMsg, @n_pos2+2, 250)
         	  	 END
         	  	 
         	  	 UPDATE #TMP_RESULT 
         	  	 SET ErrMsg = @c_ErrMsg
         	  	 WHERE Orderkey = @c_Orderkey
         	  	 AND OrderLineNumber = @c_OrderLineNumber
         	  END
         END                                     
                                                 	
         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
      END
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END  
   */         
   
   SELECT Adddate, Orderkey, ExternOrderkey, ExternLineNo, Sku, Description, Userdefine01, ErrMsg
   FROM #TMP_RESULT       
   ORDER BY Adddate, ExternOrderkey, ExternLineNo, Orderkey
END

GO