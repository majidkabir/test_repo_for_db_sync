SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE FUNCTION [dbo].[fnc_GetVC_prTaskLUTForkReplenishmentRegionConfiguration_AckData]
(
   @nSerialNo INT
)
RETURNS @tReplenishmentRegionConfig TABLE 
        (
       RegionNumber       NVARCHAR(10)
      ,RegionDescr        NVARCHAR(100)
      ,AllowCancelLicense NVARCHAR(1)
      ,AllowOverrideLoc   NVARCHAR(1)          
      ,AllowOverrideQty   NVARCHAR(1)          
      ,AllowPartialPut    NVARCHAR(1)
      ,PickupQty          NVARCHAR(1)
      ,ReplenishedQty     NVARCHAR(1)
      ,NoOfLicenseDigits  NVARCHAR(2)
      ,NoOfLocDigits      NVARCHAR(2)
      ,NoOfCheckDigits    NVARCHAR(2)
      ,ExceptionLoc       NVARCHAR(100)
      ,ConfirmSpokeLoc    NVARCHAR(1)
      ,ErrorCode          VARCHAR(20) 
      ,ErrorMessage       NVARCHAR(255)
        )
AS
    
BEGIN
   DECLARE @c_AckData NVARCHAR(4000)
         , @c_RegionNumber       NVARCHAR(10)
         , @c_RegionDescr        NVARCHAR(100)
         , @c_AllowCancelLicense NVARCHAR(1)
         , @c_AllowOverrideLoc   NVARCHAR(1)         
         , @c_AllowOverrideQty   NVARCHAR(1)          
         , @c_AllowPartialPut    NVARCHAR(1)
         , @c_PickupQty          NVARCHAR(1)
         , @c_ReplenishedQty     NVARCHAR(1)
         , @c_NoOfLicenseDigits  NVARCHAR(2)
         , @c_NoOfLocDigits      NVARCHAR(2)
         , @c_NoOfCheckDigits    NVARCHAR(2)
         , @c_ExceptionLoc       NVARCHAR(100)
         , @c_ConfirmSpokeLoc    NVARCHAR(1)
         , @c_ErrorCode          VARCHAR(20)
          ,@c_ErrorMessage       NVARCHAR(255)     
   
   DECLARE @c_Delim CHAR(1), @n_SeqNo INT  
   DECLARE @t_MessageRec TABLE (Seqno INT ,ColValue NVARCHAR(215))    
   
   SET @c_Delim = ','
   
   SELECT @c_AckData = ti.ACKData
   FROM   TCPSocket_INLog ti WITH (NOLOCK)
   WHERE  ti.SerialNo = @nSerialNo    
   
   INSERT INTO @t_MessageRec
   SELECT *
   FROM   dbo.fnc_DelimSplit(@c_Delim ,@c_AckData)  
   
   DECLARE @c_SQL       NVARCHAR(4000)
          ,@n_Index     INT
          ,@c_ColValue  NVARCHAR(215)
   
   SET @n_Index = 1
   SET @c_SQL = ''
   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY 
   FOR
       SELECT SeqNo
             ,ColValue
       FROM   @t_MessageRec
       ORDER BY Seqno
   
   OPEN CUR1
   
   FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF LEFT(@c_ColValue ,1) = '''' AND RIGHT(RTRIM(@c_ColValue) ,1) = ''''
         SET @c_ColValue = SUBSTRING(@c_ColValue ,2 ,LEN(RTRIM(@c_ColValue)) - 2)
       
         IF @n_SeqNo =  1 SET @c_RegionNumber       = @c_ColValue
         IF @n_Seqno =  2 SET @c_RegionDescr        = @c_ColValue
         IF @n_Seqno =  3 SET @c_AllowCancelLicense = @c_ColValue
         IF @n_Seqno =  4 SET @c_AllowOverrideLoc   = @c_ColValue
         IF @n_Seqno =  5 SET @c_AllowOverrideQty   = @c_ColValue
         IF @n_Seqno =  6 SET @c_AllowPartialPut    = @c_ColValue
         IF @n_Seqno =  7 SET @c_PickupQty          = @c_ColValue
         IF @n_Seqno =  8 SET @c_ReplenishedQty     = @c_ColValue
         IF @n_Seqno =  9 SET @c_NoOfLicenseDigits  = @c_ColValue
         IF @n_Seqno = 10 SET @c_NoOfLocDigits      = @c_ColValue
         IF @n_Seqno = 11 SET @c_NoOfCheckDigits    = @c_ColValue
         IF @n_Seqno = 12 SET @c_ExceptionLoc       = @c_ColValue
         IF @n_Seqno = 13 SET @c_ConfirmSpokeLoc    = @c_ColValue
         IF @n_Seqno = 14 SET @c_ErrorCode          = @c_ColValue
         IF @n_Seqno = 15 SET @c_ErrorMessage       = @c_ColValue
       
      FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue
   END
   INSERT INTO @tReplenishmentRegionConfig
   (
      RegionNumber,
      RegionDescr,
      AllowCancelLicense,
      AllowOverrideLoc,
      AllowOverrideQty,
      AllowPartialPut,
      PickupQty,
      ReplenishedQty,
      NoOfLicenseDigits,
      NoOfLocDigits,
      NoOfCheckDigits,
      ExceptionLoc,
      ConfirmSpokeLoc,
      ErrorCode,
      ErrorMessage
   )
   VALUES
   (
       @c_RegionNumber     
      ,@c_RegionDescr              
      ,@c_AllowCancelLicense       
      ,@c_AllowOverrideLoc              
      ,@c_AllowOverrideQty                   
      ,@c_AllowPartialPut               
      ,@c_PickupQty             
      ,@c_ReplenishedQty      
      ,@c_NoOfLicenseDigits             
      ,@c_NoOfLocDigits    
      ,@c_NoOfCheckDigits             
      ,@c_ExceptionLoc        
      ,@c_ConfirmSpokeLoc                      
      ,@c_ErrorCode           
      ,@c_ErrorMessage  

   )
   CLOSE CUR1
   DEALLOCATE CUR1
   
   RETURN
END;

GO