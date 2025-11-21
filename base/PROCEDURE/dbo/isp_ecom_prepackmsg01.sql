SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Ecom_PrePackMsg01                                   */
/* Creation Date: 2022-04-14                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-19434 [CN]Rituals_EcomPacking_Show GiftWrapping Massage */
/*        : in Screen                                                   */
/*                                                                      */
/* Called By: nep_n_cst_visual_pack_ecom.of_prepackmsg                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-04-14  Wan      1.0   Created & Combine DevOps Script           */
/* 2023-07-20  NJOW01   1.1   WMS-23116 Show bundle sku message         */
/* 2023-07-20  NJOW01   1.1   DEVOPS Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_Ecom_PrePackMsg01]
     @c_TaskBatchNo        NVARCHAR(10) 
   , @c_Orderkey           NVARCHAR(10) 
   , @b_Success            NVARCHAR(4000) = 1    OUTPUT         
   , @c_ErrMsg             NVARCHAR(4000) = ''   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT   = @@TRANCOUNT
         , @n_Continue              INT   = 1
         
         , @n_TotalOrderLine        INT   = 0
         , @n_TotalGiftWrapperLine  INT   = 0
         , @c_ErrMsg2               NVARCHAR(4000) --NJOW01
         , @c_Sku                   NVARCHAR(20) --NJOW01
         , @c_Userdefine06          NVARCHAR(18) --NJOW01
         , @n_Qty                   INT          --NJOW01
        
   SET @b_Success = 1     
   SET @c_errmsg   = ''

   SET @c_TaskBatchNo = ISNULL(@c_TaskBatchNo,'') 
   SET @c_Orderkey    = ISNULL(@c_Orderkey,'')

   IF @c_Orderkey = ''
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.PackTask AS pt WITH (NOLOCK)
                  JOIN ORDERDETAIL AS o WITH (NOLOCK) ON o.Orderkey = pt.Orderkey
                  WHERE pt.TaskBatchNo = @c_TaskBatchNo
                  AND pt.OrderMode LIKE 'S%'
                  AND o.Notes = 'Y'
      )
      BEGIN
         SET @c_ErrMsg = 'Gift Wrapping = ''Y'''  
      END
   END
   ELSE 
   BEGIN    
   	  --NJOW01 S
   	  SELECT OD.Sku, 
   	        SUM(OD.QtyAllocated + OD.QtyPicked) AS Qty,
   	        LEFT(OD.Userdefine06, CASE WHEN CHARINDEX('_',OD.Userdefine06) > 0 THEN CHARINDEX('_',OD.Userdefine06) - 1 ELSE LEN(OD.Userdefine06) END) AS Code,
   	        OD.Userdefine06   	        
   	  INTO #TMP_ORDDET
   	  FROM ORDERDETAIL OD (NOLOCK)
   	  WHERE OD.Orderkey = @c_Orderkey
   	  AND OD.Userdefine06 <> ''
   	  AND OD.Userdefine06 IS NOT NULL
   	  GROUP BY OD.Sku, OD.Userdefine06,
   	           LEFT(OD.Userdefine06, CASE WHEN CHARINDEX('_',OD.Userdefine06) > 0 THEN CHARINDEX('_',OD.Userdefine06) - 1 ELSE LEN(OD.Userdefine06) END)
   	           
   	  DECLARE CUR_GILFBOX CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   	     SELECT OD.Userdefine06, OD.Sku, OD.Qty
   	     FROM #TMP_ORDDET OD
   	     JOIN CODELKUP CL (NOLOCK) ON OD.Code = CL.Long 
   	     WHERE CL.ListName = 'RITVAS' 
   	     AND CL.Code LIKE '%EPACK%'   
   	     ORDER BY OD.Userdefine06, OD.Sku
   	        
      OPEN CUR_GILFBOX

      FETCH FROM CUR_GILFBOX INTO @c_Userdefine06, @c_Sku, @n_Qty
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN ( 1, 2 )
      BEGIN         	     
      	 SET @c_ErrMsg = RTRIM(ISNULL(@c_ErrMsg,'')) + RTRIM(@c_Userdefine06) + ': ' + RTRIM(@c_Sku) + ' ' + CAST(@n_Qty AS NVARCHAR) + '<CR>'
      	 
         FETCH FROM CUR_GILFBOX INTO @c_Userdefine06, @c_Sku, @n_Qty
      END
      CLOSE CUR_GILFBOX
      DEALLOCATE CUR_GILFBOX         	     	     	   
   	  --NJOW01 E
   	
      SELECT @n_TotalOrderLine = COUNT(1) 
            ,@n_TotalGiftWrapperLine = SUM(IIF(o.notes = 'Y',1,0))
      FROM ORDERDETAIL AS o WITH (NOLOCK) 
      WHERE o.OrderKey = @c_Orderkey
      GROUP BY o.OrderKey 
      
      IF @n_TotalGiftWrapperLine = 0
      BEGIN
         GOTO  QUIT_SP
      END
      
      IF @n_TotalOrderLine = @n_TotalGiftWrapperLine
      BEGIN
         SET @c_ErrMsg = RTRIM(ISNULL(@c_ErrMsg,'')) + 'Gift Wrapping = ''Y'''   --NJOW01
         GOTO  QUIT_SP
      END
      
      SELECT @c_ErrMsg2 = STRING_AGG( 'Sku: ' + o.Sku + CHAR(09) + 'Line #: ' + o.OrderLineNumber, '<CR>')  --NJOW01
         WITHIN GROUP ( ORDER BY o.Sku, o.OrderLineNumber ) 
      FROM ORDERDETAIL AS o WITH (NOLOCK) 
      WHERE o.OrderKey = @c_Orderkey
      AND o.notes = 'Y'
            
      IF @c_ErrMsg2 <> ''  --NJOW01
      BEGIN
         SET @c_ErrMsg2 =  @c_ErrMsg2 + '<CR>' 
         SET @c_ErrMsg2 = 'Gift Wrapping: <CR>' + @c_ErrMsg2 
         SET @c_ErrMsg = RTRIM(ISNULL(@c_ErrMsg,'')) + @c_ErrMsg2  --NJOW01         
      END      
   END
   
QUIT_SP:

END -- procedure

GO