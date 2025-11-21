SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_RCM_KIT_LogiWorkOrder                               */  
/* Creation Date: 03-MAR-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-18819 - Logitech Generate work order from kit           */  
/*        :                                                             */  
/* Called By: Custom RCM Menu                                           */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 24-Jan-2022 NJOW     1.0   DEVOPS combine script                     */
/************************************************************************/  
CREATE PROC [dbo].[isp_RCM_KIT_LogiWorkOrder]  
      @c_Kitkey      NVARCHAR(MAX)     
   ,  @b_success     INT OUTPUT  
   ,  @n_err         INT OUTPUT  
   ,  @c_errmsg      NVARCHAR(225) OUTPUT  
   ,  @c_code        NVARCHAR(30)=''  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_StartTCnt              INT  
         , @n_Continue               INT   
         , @c_Storerkey              NVARCHAR(15)
         , @c_Facility               NVARCHAR(5)
         , @c_Sku                    NVARCHAR(20)
         , @n_Qty                    INT
         , @c_WorkOrderKey           NVARCHAR(10)
         , @c_NewWorkOrderKey        NVARCHAR(10)
         , @n_WorkOrderLineCnt       INT = 0
         , @c_NewWorkOrderLineNumber NVARCHAR(5)     
         , @c_KitLineNumber          NVARCHAR(5)    
         , @c_Type                   NVARCHAR(5)
         , @c_ParentSku              NVARCHAR(20) = ''
         , @n_ParentQty              INT = 0
         , @n_CompQty                INT = 0   
         , @n_AP1B_Cnt               INT = 0        
         , @c_Notes2                 NVARCHAR(2000)=''
         , @c_IsCreateBOM            NVARCHAR(5)='Y'
         , @c_AP1B_Cond              NVARCHAR(1000) = ''
         , @c_SQL                    NVARCHAR(2000)
         , @c_AP1B_Short             NVARCHAR(10)
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
   
   CREATE TABLE #TMP_BOM ([Sequence]     INT IDENTITY(1,1), 
                          Storerkey    NVARCHAR(15) NULL,
                          Sku          NVARCHAR(20) NULL,
                          ComponentSku NVARCHAR(20) NULL,
                          Qty          INT NULL)
     
   IF @n_continue IN(1,2)
   BEGIN   
      SELECT @c_Storerkey = K.Storerkey, 
             @c_Facility = K.Facility
      FROM KIT K (NOLOCK)
      WHERE K.Kitkey = @c_Kitkey
      
      SELECT @c_WorkOrderkey = WO.WorkOrderkey 
      FROM WORKORDER WO (NOLOCK)
      WHERE WO.Storerkey = @c_Storerkey
      AND WO.ExternWorkOrderkey = @c_Kitkey
      
      IF ISNULL(@c_WorkOrderkey,'') <> ''            
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63300
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Workorder ' + RTRIM(@c_WorkOrderkey) + ' already exists for current kit (isp_RCM_KIT_LogiWorkOrder)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END
      
      SELECT @c_Notes2 = Notes2
      FROM CODELKUP (NOLOCK)
      WHERE ListName = 'RCMCONFIG'
      AND Storerkey = @c_Storerkey
      AND Long = 'isp_RCM_KIT_LogiWorkOrder'
      AND Short = 'STOREDPROC'
      AND UDF01 = 'KIT'
      
      SELECT @c_IsCreateBOM = dbo.fnc_GetParamValueFromString('@c_IsCreateBOM', @c_Notes2, @c_IsCreateBOM)      

      DECLARE CUR_CUSPARM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR       
         SELECT Short
         FROM CODELKUP (NOLOCK)
         WHERE Storerkey = @c_Storerkey 
         AND listname = 'CUSTPARAM' 
         AND code = 'LGKITDTL08'
         
      OPEN CUR_CUSPARM   
      
      FETCH NEXT FROM CUR_CUSPARM INTO @c_AP1B_Short 
      
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)             
      BEGIN    
      	 IF ISNULL(@c_AP1B_Cond,'') = '' 	 
      	    SET @c_AP1B_Cond = ' ISNULL(KT.Lottable08,'''') LIKE ''' + @c_AP1B_Short + ''' '
      	 ELSE
      	    SET @c_AP1B_Cond =  RTRIM(@c_AP1B_Cond)  + ' OR ISNULL(KT.Lottable08,'''') LIKE ''' + @c_AP1B_Short + ''' '      	    

         FETCH NEXT FROM CUR_CUSPARM INTO @c_AP1B_Short       	
      END
      CLOSE CUR_CUSPARM
      DEALLOCATE CUR_CUSPARM     	                           
      
      IF ISNULL(@c_AP1B_Cond,'') = ''
         SET @c_AP1B_Cond = ' ISNULL(KT.Lottable08,'''') LIKE ''AP1B%'' ' 
   END
   
   IF @n_continue IN(1,2) AND @c_IsCreateBOM = 'Y'
   BEGIN
      IF EXISTS(SELECT 1 
                FROM KITDETAIL KD (NOLOCK)
                JOIN BILLOFMATERIAL BM (NOLOCK) ON KD.Storerkey = BM.Storerkey AND KD.Sku =  BM.Sku
                WHERE KD.Kitkey = @c_KitKey
                AND KD.Type = 'T')
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63310
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Parent Sku already exists in Bill of Material table. (isp_RCM_KIT_LogiWorkOrder)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END                
   END

   /*
   IF @n_continue IN(1,2)
   BEGIN
      IF EXISTS(SELECT 1 
                FROM KITDETAIL KD (NOLOCK)
                WHERE KD.Kitkey = @c_KitKey
                AND KD.Type = 'F'
                AND ISNULL(KD.Lottable08,'') <> 'AP1BWP')
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63320
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': AP1BWP is not exist in Kitdetail. (isp_RCM_KIT_LogiWorkOrder)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END                
   END
   */

   IF @n_continue IN(1,2)
   BEGIN
      IF EXISTS(SELECT 1 
                FROM KITDETAIL KD (NOLOCK)
                WHERE KD.Kitkey = @c_KitKey
                AND KD.Type = 'F'
                AND ISNULL(KD.Lot,'') = '')
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63330
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Kitting is not fully allocated. (isp_RCM_KIT_LogiWorkOrder)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END                
   END
   
   /*IF @n_continue IN(1,2)
   BEGIN
      IF EXISTS(SELECT 1 
                FROM KITDETAIL KD (NOLOCK)
                JOIN LOTATTRIBUTE LA (NOLOCK) ON KD.Lot = LA.Lot
                WHERE KD.Kitkey = @c_KitKey
                AND KD.Type = 'F'
                AND LEFT(ISNULL(LA.Lottable08,''),4) <> 'AP1B')
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63340
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Only AP1B% stock is allowed. (isp_RCM_KIT_LogiWorkOrder)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END                
   END*/  
   
   IF @n_continue IN(1,2)
   BEGIN   
      SET @b_success = 1	  
      EXECUTE nspg_GetKey
             'WorkOrder                     '
            ,10 
            ,@c_NewWorkOrderKey OUTPUT 
            ,@b_success         OUTPUT 
            ,@n_err             OUTPUT 
            ,@c_errmsg          OUTPUT
      
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         GOTO QUIT_SP
      END
      
      INSERT INTO WorkOrder
          (
          	WorkOrderKey,
          	ExternWorkOrderKey,
          	StorerKey,
          	Facility,
          	[Status],
          	ExternStatus,
          	[Type],
          	Reason
         )      	     
      VALUES 
        (@c_NewWorkOrderKey,
         @c_KitKey,
         @c_Storerkey,
         @c_Facility,
         '0',
         '0',
         'REWORK',
         'VASADH'
         )
         
      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63350
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert WORKORDER Table Failed! (isp_RCM_KIT_LogiWorkOrder)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END
                       
      SET @c_SQL = N'
      DECLARE CUR_KITDET CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT KT.Sku, MIN(KT.KITLineNumber), 
                SUM(KT.Qty), 
                KT.Type,
                SUM(CASE WHEN ' + @c_AP1B_Cond + ' THEN 1 ELSE 0 END) AS AP1B_Cnt
                --SUM(CASE WHEN ISNULL(KT.Lottable08,'''') LIKE @c_AP1B_Cond THEN 1 ELSE 0 END) AS AP1B_Cnt
                --SUM(CASE WHEN LEFT(ISNULL(KT.Lottable08,''),4) = ''AP1B'' THEN 1 ELSE 0 END) AS AP1B_Cnt
         FROM KITDETAIL KT (NOLOCK)
         WHERE KT.Kitkey = @c_KitKey
         GROUP BY KT.Sku, KT.Type
         ORDER BY CASE WHEN KT.Type = ''T'' THEN 1 ELSE 2 END, MIN(KT.KITLineNumber)'

      EXEC sp_executesql @c_SQL,
         N'@c_Kitkey NVARCHAR(10)', 
         @c_Kitkey

      OPEN CUR_KITDET   
      
      FETCH NEXT FROM CUR_KITDET INTO @c_Sku, @c_KitLineNumber, @n_Qty, @c_Type, @n_AP1B_Cnt 
      
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)             
      BEGIN         	                  
      	 IF @c_Type = 'T' AND ISNULL(@c_ParentSku,'') = ''           
      	 BEGIN
      	    SET @c_ParentSku = @c_Sku
      	    SET @n_ParentQty = @n_Qty
      	 END
      	 
      	 IF @c_Type = 'F' AND @c_ParentSku <> @c_Sku AND @n_AP1B_Cnt > 0 AND @c_IsCreateBOM = 'Y'
      	 BEGIN      	 	
      	 	  SET @n_CompQty = 0
      	 	  
      	 	  IF ISNULL(@n_ParentQty,0) = 0 OR @n_Qty % @n_ParentQty > 0 
      	 	  BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63360
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Divide Error when calculate Component Sku Qty (isp_RCM_KIT_LogiWorkOrder)' + ' ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' )'
               BREAK                  
            END
      	 	  
      	 	  SET @n_CompQty = @n_Qty / @n_ParentQty      	 	  
      	 	     
      	 	  INSERT INTO #TMP_BOM (Storerkey, Sku, ComponentSku, Qty)
      	 	  VALUES (@c_Storerkey, @c_ParentSku, @c_Sku, @n_CompQty)
      	 END
      	 
      	 IF @n_AP1B_Cnt > 0 OR @c_Type = 'T'
      	 BEGIN
            SET @n_WorkOrderLineCnt = @n_WorkOrderLineCnt + 1	
       	    SET @c_NewWorkOrderLineNumber = RIGHT('00000'+RTRIM(LTRIM(CAST(@n_WorkOrderLineCnt AS NVARCHAR))),5)      	
       	    SET @c_KitLineNumber = RIGHT(@c_NewWorkOrderLineNumber,3)
       	    
            INSERT INTO WorkOrderDetail
                (
                	WorkOrderKey,
                	WorkOrderLineNumber,
                	ExternWorkOrderKey,
                	ExternLineNo,
                	[Type],
                	Reason,
                	Unit,
                	Qty,
                	[Status],
                	StorerKey,
                	Sku
                )       	 
            VALUES
               (@c_NewWorkOrderKey,
                @c_NewWorkOrderLineNumber,
                @c_Kitkey,
                @c_KitLineNumber,
                'REWORK',
                'VASADH',
                'K',
                @n_Qty,
                '0',
                @c_Storerkey,
                @c_Sku
               )      
               
            SELECT @n_err = @@ERROR
            IF  @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63320
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert WORKORDERDETAIL Table Failed! (isp_RCM_KIT_LogiWorkOrder)' + ' ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END   
         END          
       	 
         FETCH NEXT FROM CUR_KITDET INTO @c_Sku, @c_KitLineNumber, @n_Qty, @c_Type, @n_AP1B_Cnt 
      END
      CLOSE CUR_KITDET
      DEALLOCATE CUR_KITDET                  
   END
   
   IF @n_continue IN(1,2) AND @c_IsCreateBOM = 'Y'
   BEGIN
      INSERT INTO BILLOFMATERIAL (Storerkey, Sku, ComponentSku, Sequence, Qty, ParentQty, UDF01)
         SELECT Storerkey, Sku, ComponentSku, 
                RIGHT('00'+RTRIM(LTRIM(CAST(Sequence AS NVARCHAR))),2),
                Qty, 1, @c_Kitkey
         FROM #TMP_BOM
         ORDER BY Sequence

      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63370
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert BILLOFMATERIAL Table Failed! (isp_RCM_KIT_LogiWorkOrder)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END             
   END
   
   IF @n_continue IN (1,2) AND ISNULL(@c_ParentSku,'') <> ''    
   BEGIN
   	  UPDATE SKU WITH (ROWLOCK)
   	  SET ProductModel = 'COPACK',  
   	      TrafficCop = NULL
   	  WHERE Storerkey = @c_Storerkey
   	  AND Sku = @c_ParentSku
   	  
      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63380
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update SKU Table Failed! (isp_RCM_KIT_LogiWorkOrder)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END                	  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RCM_KIT_LogiWorkOrder'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
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