SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF12                                            */
/* Creation Date: 27-Jun-2019                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-15009 CN Natural Beauty pack confirm update serial no      */
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 04-Nov-2022  WLChooi 1.1   DevOps Combine Script                        */
/* 04-Nov-2022  WLChooi 1.1   Performance Tuning (WL01)                    */ 
/* 22-Mar-2023  NJOW01  1.2   WMS-21989 CN Yonex. Update serialno.sku and  */
/*                            UCC.Sku from UPC.Sku                         */
/***************************************************************************/  
CREATE   PROC [dbo].[ispPAKCF12]  
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
  
   DECLARE @b_Debug           INT
         , @n_Continue        INT 
         , @n_StartTCnt       INT 
 
   DECLARE @C_Orderkey        NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)
         , @c_Sku             NVARCHAR(20)
         --, @c_Lot             NVARCHAR(10)
         --, @c_ID              NVARCHAR(18)
         , @n_Qty             INT
         , @c_SerialNoKey     NVARCHAR(10)
         , @c_SQL             NVARCHAR(MAX)
         , @c_Orderkey1sttime NVARCHAR(10)
         , @c_DropID          NVARCHAR(20)
         , @n_CartonNo        INT
         , @c_LabelLine       NVARCHAR(5)
         , @c_PostPackCfgOpt5 NVARCHAR(4000)  --NJOW01
         , @c_UpdateSerial_UCCSkuFromUPC NVARCHAR(30) --NJOW01
         , @c_Facility        NVARCHAR(5) --NJOW01
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug  = 0 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   --NJOW01 S
   SELECT @c_Storerkey = O.Storerkey
         ,@c_Facility = O.Facility
   FROM PACKHEADER PH (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   WHERE PH.PickslipNo = @c_PIckslipno      	
   
   SELECT @c_PostPackCfgOpt5 = SC.Option5                            
   FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '','PostPackconfirmSP') AS SC
   
   SELECT @c_UpdateSerial_UCCSkuFromUPC = dbo.fnc_GetParamValueFromString('@c_UpdateSerial_UCCSkuFromUPC', @c_PostPackCfgOpt5, @c_UpdateSerial_UCCSkuFromUPC)
   --NJOW01 E
   
   SELECT PD.Storerkey, PD.Sku, PD.DropID, MAX(PD.CartonNo) AS CartonNo, MAX(PD.LabelLine) AS LabelLine     
   INTO #TMP_DROPID
   FROM PACKHEADER PH (NOLOCK) 
   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
   WHERE PH.PickslipNo = @c_Pickslipno
   AND ISNULL(PD.DropID,'') <> ''
   GROUP BY PD.Storerkey, PD.Sku, PD.DropID

   CREATE INDEX IDX_TMP_DROPID_DropID ON #TMP_DROPID (Storerkey, Sku, DropID)   --WL01
      
   --NJOW01 S
   IF @c_UpdateSerial_UCCSkuFromUPC = 'Y'                   
   BEGIN
      DECLARE cur_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT DISTINCT Userdefine01, Storerkey
         FROM SERIALNO (NOLOCK)
         WHERE Pickslipno = @c_Pickslipno
         AND Userdefine01 <> ''
         
      OPEN cur_UCC  

      FETCH NEXT FROM cur_UCC INTO @c_DropID, @c_Storerkey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN      	 
      	 UPDATE UCC WITH (ROWLOCK)
      	 SET UCC.Sku = U.Sku,
      	     UCC.TrafficCop = NULL,
             UCC.EditDate = GETDATE(),
             UCC.EditWho = SUSER_SNAME()
      	 FROM UCC
      	 CROSS APPLY (SELECT TOP 1 UPC.Sku
      	              FROM SERIALNO SR (NOLOCK) 
      	              JOIN UPC (NOLOCK) ON SR.Storerkey = UPC.Storerkey AND SR.Userdefine02 = UPC.Upc
      	              WHERE SR.Userdefine01 = UCC.UCCNo AND SR.Storerkey = UCC.Storerkey --AND SR.Sku = UCC.Sku
      	              AND SR.Pickslipno = @c_Pickslipno
      	              ) U
      	 WHERE UCC.UccNo = @c_DropID
      	 AND UCC.Storerkey = @c_Storerkey
      	 
         FETCH NEXT FROM cur_UCC INTO @c_DropID, @c_Storerkey
      END
      CLOSE cur_UCC
      DEALLOCATE cur_UCC         
      
      DECLARE cur_ORDLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.Orderkey, OD.OrderLineNumber, OD.Storerkey, OD.Sku, SUM(PD.Qty) AS Qty
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey      
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku      
      JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
      WHERE PH.Pickslipno = @c_Pickslipno
      AND SKU.SerialNoCapture IN ('1','3')
      AND (EXISTS(SELECT 1 FROM SERIALNO SN (NOLOCK)
                  LEFT JOIN UPC (NOLOCK) ON SN.Storerkey = UPC.Storerkey AND SN.Userdefine02 = UPC.Upc     
                  WHERE SN.Orderkey = O.Orderkey
                  AND SN.Storerkey = SKU.Storerkey
                  AND (SN.Sku = SKU.Sku
                       OR UPC.Sku = SKU.Sku)
                  )
           OR EXISTS(SELECT 1 FROM #TMP_DROPID D
                 WHERE D.Storerkey = OD.Storerkey  --NJOW01 fix OD
                 AND D.Sku = OD.Sku)               --NJOW01 fix OD
           )
      GROUP BY O.Orderkey, OD.OrderLineNumber, OD.Storerkey, OD.Sku
      ORDER BY OD.Sku, OD.OrderLineNumber      
   END  --NJOW01 E    
   ELSE 
   BEGIN   
      DECLARE cur_ORDLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.Orderkey, OD.OrderLineNumber, OD.Storerkey, OD.Sku, SUM(PD.Qty) AS Qty
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey      
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku      
      JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
      WHERE PH.Pickslipno = @c_Pickslipno
      AND SKU.SerialNoCapture IN ('1','3')
      AND (EXISTS(SELECT 1 FROM SERIALNO SN (NOLOCK)
                 WHERE SN.Orderkey = O.Orderkey
                 AND SN.Storerkey = SKU.Storerkey
                 AND SN.Sku = SKU.Sku)
           OR EXISTS(SELECT 1 FROM #TMP_DROPID D
                 WHERE D.Storerkey = OD.Storerkey  --NJOW01 fix OD
                 AND D.Sku = OD.Sku)               --NJOW01 fix OD
           )
      GROUP BY O.Orderkey, OD.OrderLineNumber, OD.Storerkey, OD.Sku
      ORDER BY OD.Sku, OD.OrderLineNumber
   END
   
   OPEN cur_ORDLINE  
          
   FETCH NEXT FROM cur_ORDLINE INTO @C_Orderkey, @c_OrderLineNumber, @c_Storerkey, @c_Sku, @n_Qty

   IF @b_Debug = 1
   BEGIN
      SELECT  '@C_Orderke=' + RTRIM(@C_Orderkey), '@c_OrderLineNumber='+RTRIM(@c_OrderLineNumber), 
              '@c_Storerkey=' + RTRIM(@c_Storerkey), '@c_Sku=' + RTRIM(@c_Sku), 
              '@n_Qty=' + CAST(@n_Qty AS NVARCHAR)
   END
   
   SET @c_Orderkey1sttime = @c_Orderkey
          
   WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
   BEGIN      	      	   	
      IF ISNULL(@c_Orderkey1sttime,'') <> ''
      BEGIN
         UPDATE SERIALNO WITH (ROWLOCK)
      	  SET Pickslipno = ''
      	     ,CartonNo = 0
      	     ,LabelLine = ''
      	     ,TrafficCop = NULL
      	     --,OrderLineNumber = ''
              ,EditDate = GETDATE()   --WL01
              ,EditWho = SUSER_SNAME()   --WL01
      	  WHERE (Orderkey = @c_Orderkey
      	  OR EXISTS(SELECT 1 FROM #TMP_DROPID
      	       	    WHERE #TMP_DROPID.DropID = SERIALNO.Userdefine01
      	            ) 
      	         )   
      	  AND Storerkey = @c_Storerkey
      
         SET @n_Err = @@ERROR
                             
         IF @n_Err <> 0
         BEGIN
             SELECT @n_Continue = 3 
             SELECT @n_Err = 38010
             SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update SERIALNO Table Failed. (ispPAKCF12)'
         END                      
         
         SET @c_Orderkey1sttime = ''                  	 
      END
   	
   	  --Serial no pack by UCC
   	      --Packdetail.dropid(stamp) and Serialno.userdefine01(interface) are UCC#
   	      --no stamping in serialno table when scanning.
   	      --1 carton 1 ucc#
   	  --Serial no pack by Sku (antidiversion)
   	      --stamp serialno.orderkey, status = '6' and orderlinenumumber = cartonno when scanning serial#
   	      --packdetail.dropid is empty
   	      --one carton one label line per sku   	  
      SET @c_SQL = ' 
   	    DECLARE cur_SERIALNO CURSOR FAST_FORWARD READ_ONLY FOR 
   	    SELECT TOP ' + RTRIM(CAST(@n_Qty AS NVARCHAR)) + ' SR.SerialNokey, ISNULL(TD.DropID,''''), 
   	           CASE WHEN TD.DropID IS NULL THEN CAST(SR.OrderLineNumber AS INT) ELSE ISNULL(TD.CartonNo,0) END, 
   	           ISNULL(TD.LabelLine,'''') 
   	    FROM SERIALNO SR (NOLOCK) ' +
   	    CASE WHEN @c_UpdateSerial_UCCSkuFromUPC = 'Y' THEN  --NJOW01
   	       ' LEFT JOIN UPC (NOLOCK) ON SR.Storerkey = UPC.Storerkey AND SR.Userdefine02 = UPC.Upc 
   	         LEFT JOIN #TMP_DROPID TD ON SR.Userdefine01 = TD.DropID AND SR.Storerkey = TD.Storerkey AND (SR.Sku = TD.Sku OR UPC.Sku = TD.Sku) '
   	    ELSE       	      	    
   	       ' LEFT JOIN #TMP_DROPID TD ON SR.Userdefine01 = TD.DropID AND SR.Storerkey = TD.Storerkey AND SR.Sku = TD.Sku '
   	    END +   
   	  ' WHERE (SR.Orderkey = @c_Orderkey OR TD.DropID IS NOT NULL)
   	    AND SR.Storerkey = @c_Storerkey ' +
   	    CASE WHEN @c_UpdateSerial_UCCSkuFromUPC = 'Y' THEN  --NJOW01
   	       ' AND (SR.Sku = @c_Sku OR UPC.Sku = @c_Sku) '
   	    ELSE   
   	       ' AND SR.Sku = @c_Sku '
   	    END +   	       
   	  ' AND SR.Pickslipno = ''''
   	    ORDER BY SR.Userdefine01, SR.SerialNokey '

      EXEC sp_executesql @c_SQL,
         N'@c_Orderkey NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20)', 
         @c_Orderkey,
         @c_Storerkey,
         @c_Sku
                  
      IF @b_Debug = 1
         PRINT @c_SQL         

      OPEN cur_SERIALNO  

      FETCH NEXT FROM cur_SERIALNO INTO @c_SerialNoKey, @c_DropID, @n_CartonNo, @c_LabelLine
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	 IF @b_Debug = 1
         BEGIN
            SELECT  '@c_SerialNoKey=' + RTRIM(@c_SerialNoKey) + ' @c_Dropid=' + RTRIM(@c_DropID) + ' @n_cartonno=' + RTRIM(CAST(@c_DropID AS NVARCHAR)) + ' @c_LabelLine=' + RTRIM(@c_LabelLine) 
         END
         
         IF ISNULL(@c_DropId,'') = ''
         BEGIN
         	 SELECT TOP 1 @c_LabelLine = PD.LabelLine
         	 FROM PACKDETAIL PD (NOLOCK)
         	 WHERE PD.Pickslipno = @c_Pickslipno
         	 AND PD.Storerkey = @c_Storerkey
         	 AND PD.Sku = @c_Sku
         	 AND PD.CartonNo = @n_CartonNo
         END
         
         IF @c_UpdateSerial_UCCSkuFromUPC = 'Y'  --NJOW01
         BEGIN
      	    UPDATE SERIALNO WITH (ROWLOCK)
      	    SET SERIALNO.Orderkey = @c_Orderkey
      	       ,SERIALNO.OrderLineNumber = @c_OrderLineNumber
      	       ,SERIALNO.Pickslipno = @c_Pickslipno
      	       ,SERIALNO.CartonNo = @n_CartonNo
      	       ,SERIALNO.Labelline = @c_LabelLine
      	       ,SERIALNO.Status = '6'
      	       ,SERIALNO.TrafficCop = NULL
               ,SERIALNO.EditDate = GETDATE()   --WL01
               ,SERIALNO.EditWho = SUSER_SNAME()   --WL01
               ,SERIALNO.Sku = CASE WHEN UPC.Sku IS NOT NULL THEN UPC.Sku ELSE SERIALNO.Sku END               
            FROM SERIALNO
            LEFT JOIN UPC (NOLOCK) ON SERIALNO.Userdefine02 = UPC.Upc AND SERIALNO.Storerkey = UPC.Storerkey
      	    WHERE SERIALNO.SerialNokey = @c_SerialNokey
         END
         ELSE
         BEGIN
      	    UPDATE SERIALNO WITH (ROWLOCK)
      	    SET Orderkey = @c_Orderkey
      	       ,OrderLineNumber = @c_OrderLineNumber
      	       ,Pickslipno = @c_Pickslipno
      	       ,CartonNo = @n_CartonNo
      	       ,Labelline = @c_LabelLine
      	       ,Status = '6'
      	       ,TrafficCop = NULL
               ,EditDate = GETDATE()   --WL01
               ,EditWho = SUSER_SNAME()   --WL01
      	    WHERE SerialNokey = @c_SerialNokey
      	 END

         SET @n_Err = @@ERROR
                             
         IF @n_Err <> 0
         BEGIN
             SELECT @n_Continue = 3 
             SELECT @n_Err = 38020
             SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update SERIALNO Table Failed. (ispPAKCF12)'
         END                               	          	  
      	  
         FETCH NEXT FROM cur_SERIALNO INTO @c_SerialNoKey, @c_DropID, @n_CartonNo, @c_LabelLine
      END
      CLOSE cur_SERIALNO
      DEALLOCATE cur_SERIALNO      	       	       	 
   	 
      FETCH NEXT FROM cur_ORDLINE INTO @C_Orderkey, @c_OrderLineNumber, @c_Storerkey, @c_Sku, @n_Qty    
   END
   CLOSE cur_ORDLINE
   DEALLOCATE cur_ORDLINE
                                  
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF12'
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