SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispMBOLShipCloseSerialNo                           */  
/* Creation Date: 14-MAR-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-8263 MBOL Ship close serial no status                   */  
/*                                                                      */  
/* Called By: isp_ShipMBOL                                              */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */ 
/* 20-Nov-2019  CheeMun	1.0   INC0903488 - Filter only update empty     */
/*                            Pickdetailkey in PACKSERIALNO             */
/* 01-Sep-2020  WLChooi 1.1   WMS-15001 - MBOLShipCloseSerialNo - No    */
/*                            check Packheader and PACKSERIALNO Table   */
/*                            (WL01)                                    */
/* 09-Aug-2023  NJOW01  1.2   WMS-22379 Support update serialno status=9*/
/*                            by pickserialno table                     */
/* 09-Aug-2023  NJOW01  1.2   DEVOPS Combine Script                     */  
/************************************************************************/  
CREATE   PROC [dbo].[ispMBOLShipCloseSerialNo]    
     @c_MBOLKey     NVARCHAR(10)  
   , @b_Success     INT           OUTPUT    
   , @n_Err         INT           OUTPUT    
   , @c_ErrMsg      NVARCHAR(250) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE  @n_Continue    INT     
         ,  @n_StartTCnt   INT  -- Holds the current transaction count     
         ,  @c_SerialNoKey NVARCHAR(10)
         ,  @c_Orderkey    NVARCHAR(10) --NJOW01               
         ,  @c_SerialNo    NVARCHAR(50) --NJOW01
         ,  @c_Sku         NVARCHAR(20) --NJOW01
  
   DECLARE  @c_SQL            NVARCHAR(MAX)      
         ,  @c_SQLParm        NVARCHAR(MAX)  
         
   CREATE TABLE #TMP_SERIALNO (SerialNoKey NVARCHAR(10), Orderkey NVARCHAR(10)) --NJOW01
    
   SET @n_StartTCnt  =  @@TRANCOUNT
   SET @n_Continue   =  1
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  ''  
   
   --WL01 START
   DECLARE @c_MBOLShipCloseSerialNo NVARCHAR(10) = '',
           @c_Storerkey             NVARCHAR(15) = ''

   SELECT @c_Storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE MBOLKey = @c_MBOLKey

   SELECT @c_MBOLShipCloseSerialNo = SValue
   FROM StorerConfig (NOLOCK)
   WHERE StorerKey = @c_Storerkey AND Configkey = 'MBOLShipCloseSerialNo'
   --WL01 END

   /*IF NOT EXISTS(SELECT 1 
                 FROM MBOLDETAIL MD (NOLOCK)
                 JOIN ORDERDETAIL OD (NOLOCK) ON MD.Orderkey = OD.Orderkey
                 JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
                 WHERE MD.mbolkey = @c_Mbolkey
                 AND SKU.SerialNoCapture IN('1','3')) 
   BEGIN     
   	  GOTO EXIT_SP
   END*/             
   
   --WL01 START
   IF @c_MBOLShipCloseSerialNo = '1'
   BEGIN
   	  INSERT INTO #TMP_SERIALNO (SerialNokey, Orderkey)   --NJOW01
         SELECT SER.SerialNoKey, O.Orderkey 
         FROM MBOLDETAIL MD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
         --JOIN PACKHEADER PH (NOLOCK) ON O.Orderkey = PH.Orderkey
         --JOIN PACKSERIALNO PS (NOLOCK) ON PH.PickSlipNo = PS.PickslipNo AND PH.Storerkey = PS.Storerkey
         JOIN SERIALNO SER (NOLOCK) ON  O.Storerkey = SER.Storerkey AND O.Orderkey = SER.OrderKey
         WHERE MD.Mbolkey = @c_MBOLKey
         --AND PH.Status = '9'  	  
   END
   ELSE
   BEGIN
   	  INSERT INTO #TMP_SERIALNO (SerialNokey, Orderkey)   --NJOW01
         SELECT SER.SerialNoKey, O.Orderkey 
         FROM MBOLDETAIL MD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
         JOIN PACKHEADER PH (NOLOCK) ON O.Orderkey = PH.Orderkey
         JOIN PACKSERIALNO PS (NOLOCK) ON PH.PickSlipNo = PS.PickslipNo AND PH.Storerkey = PS.Storerkey
         JOIN SERIALNO SER (NOLOCK) ON  PS.Storerkey = SER.Storerkey AND PS.SKU = SER.Sku AND PS.SerialNo = SER.SerialNo
         WHERE MD.Mbolkey = @c_MBOLKey AND ISNULL(PS.PICKDETAILKEY, '') = '' --INC0903488
         AND PH.Status = '9'

      --NJOW01 S      
      IF EXISTS(SELECT TOP 1 1 
                FROM MBOLDETAIL MD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
                JOIN PICKDETAIL PD (NOLOCK)ON O.Orderkey = PD.Orderkey         
                JOIN PICKSERIALNO PS (NOLOCK) ON PD.Pickdetailkey = PS.Pickdetailkey AND PD.Storerkey = PS.Storerkey AND PD.Sku = PS.Sku
                JOIN SERIALNO SER (NOLOCK) ON  PS.Storerkey = SER.Storerkey AND PS.SKU = SER.Sku AND PS.SerialNo = SER.SerialNo
                WHERE MD.Mbolkey = @c_MBOLKey)
      BEGIN                                     
      	 SELECT TOP 1 @c_Serialno = PS.SerialNo,
      	        @c_Sku = PS.Sku,
      	        @c_Orderkey = PD.Orderkey
      	 FROM MBOLDETAIL MD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
         JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey      
         JOIN PICKSERIALNO PS (NOLOCK) ON PD.Pickdetailkey = PS.Pickdetailkey AND PD.Storerkey = PS.Storerkey AND PD.Sku = PS.Sku
         JOIN SERIALNO SER (NOLOCK) ON  PS.Storerkey = SER.Storerkey AND PS.SKU = SER.Sku AND PS.SerialNo = SER.SerialNo         
         WHERE MD.Mbolkey = @c_MBOLKey
         AND SER.Status < '5'
         ORDER BY PS.SerialNo
         
         IF ISNULL(@c_SerialNo,'') <> ''
         BEGIN
            SET @n_Continue= 3    
            SET @n_Err     = 63501    
            SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Ship rejected. Serial# is not picked status(5) yet. Serial#: ' + RTRIM(@c_Serialno) + ' Sku: ' + RTRIM(@c_Sku) + ' Order#: ' + RTRIM(@c_Orderkey) + ' (ispMBOLShipCloseSerialNo)'         	
         END
         ELSE
         BEGIN      	 
   	        INSERT INTO #TMP_SERIALNO (SerialNokey, Orderkey)   
               SELECT SER.SerialNoKey, O.Orderkey 
               FROM MBOLDETAIL MD (NOLOCK)
               JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
               JOIN PICKDETAIL PD (NOLOCK)ON O.Orderkey = PD.Orderkey         
               JOIN PICKSERIALNO PS (NOLOCK) ON PD.Pickdetailkey = PS.Pickdetailkey AND PD.Storerkey = PS.Storerkey AND PD.Sku = PS.Sku
               JOIN SERIALNO SER (NOLOCK) ON  PS.Storerkey = SER.Storerkey AND PS.SKU = SER.Sku AND PS.SerialNo = SER.SerialNo
               WHERE MD.Mbolkey = @c_MBOLKey 
         END
      END   
      --NJOW01 E
   END
   --WL01 END
   
   DECLARE CUR_DISCPACKSERIAL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  --NJOW01
      SELECT DISTINCT SerialNoKey, Orderkey
      FROM #TMP_SERIALNO
      ORDER BY SerialNokey
         
   OPEN CUR_DISCPACKSERIAL  
  
   FETCH NEXT FROM CUR_DISCPACKSERIAL INTO @c_SerialNoKey, @c_Orderkey

   WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
   BEGIN    
      UPDATE SERIALNO WITH (ROWLOCK)
      SET Status = '9'
          --Orderkey = @c_Orderkey
      WHERE SerialNokey = @c_SerialNokey
                     
      IF @@ERROR <> 0 
      BEGIN  
         SET @n_Continue= 3    
         SET @n_Err     = 63502    
         SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update SerialNo Table  (ispMBOLShipCloseSerialNo)'
      END 

      FETCH NEXT FROM CUR_DISCPACKSERIAL INTO @c_SerialNoKey, @c_Orderkey
   END   

EXIT_SP:

   IF CURSOR_STATUS('LOCAL' , 'CUR_DISCPACKSERIAL') in (0 , 1)
   BEGIN
      CLOSE CUR_DISCPACKSERIAL
      DEALLOCATE CUR_DISCPACKSERIAL   
   END

   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispMBOLShipCloseSerialNo'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN    
   END    
   ELSE    
   BEGIN    
      SET @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END      
      RETURN    
   END        
END -- Procedure  

GO